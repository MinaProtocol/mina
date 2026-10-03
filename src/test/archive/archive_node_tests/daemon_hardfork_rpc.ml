(* The daemon side of the hard fork announcement, against a mock archive.

   The mock is an RPC server implementing the archive's own Send_archive_diff,
   so the daemon code under test -- Archive_client.dispatch_hardfork_config and
   Mina_run's send and heartbeat -- runs unchanged over a real connection. The
   mock records every configuration it accepts and can refuse a number of
   them first, which is how a busy or broken archive answers.

   No postgres and no archive process: these cases run anywhere.

   Run:
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test daemon_hardfork_rpc
*)

open Async
open Core

let logger = Logger.null ()

module Mock_archive = struct
  type t =
    { port : int
    ; received : string Queue.t
    ; refusals : int ref
    ; server : (Socket.Address.Inet.t, int) Tcp.Server.t
    }

  (* Refuses the first [refuse] announcements, then accepts. A refusal is an
     exception in the implementation, which the client sees as an RPC error,
     exactly as it sees one from the real archive. *)
  let start ?(refuse = 0) () =
    let received = Queue.create () in
    let refusals = ref 0 in
    let implementations =
      Rpc.Implementations.create_exn ~on_unknown_rpc:`Close_connection
        ~implementations:
          [ Rpc.Rpc.implement Archive_lib.Rpc.t (fun () diff ->
                match diff with
                | Archive_lib.Diff.Transition_frontier
                    (Archive_lib.Diff.Transition_frontier.Hardfork_config
                      { config_json } ) ->
                    if !refusals < refuse then (
                      incr refusals ;
                      failwith "mock archive refuses" )
                    else (
                      Queue.enqueue received config_json ;
                      Deferred.unit )
                | _ ->
                    failwith "mock archive got a diff that is not a fork" )
          ]
    in
    let%map server =
      Rpc.Connection.serve ~implementations
        ~initial_connection_state:(fun _ _ -> ())
        ~where_to_listen:Tcp.Where_to_listen.of_port_chosen_by_os ()
    in
    { port = Tcp.Server.listening_on server; received; refusals; server }

  let location t =
    { Cli_lib.Flag.Types.name = "--archive-address"
    ; value = Host_and_port.create ~host:"127.0.0.1" ~port:t.port
    }

  let stop t = Tcp.Server.close t.server
end

let with_mock ?refuse f =
  let%bind mock = Mock_archive.start ?refuse () in
  Monitor.protect ~finally:(fun () -> Mock_archive.stop mock) (fun () -> f mock)

let fork_config_json =
  {json|{"proof":{"fork":{"state_hash":"3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ","blockchain_length":10,"global_slot_since_genesis":12}}}|json}

let run f () = Thread_safe.block_on_async_exn f

(* What the daemon sends is what it generated, byte for byte: the archive
   keeps it verbatim for the later steps of the hand-over. *)
let delivers_the_config_verbatim =
  run (fun () ->
      with_mock (fun mock ->
          let%map result =
            Mina_lib.Archive_client.dispatch_hardfork_config ~max_tries:1
              ~logger
              (Mock_archive.location mock)
              ~config_json:fork_config_json
          in
          Or_error.ok_exn result ;
          [%test_eq: string list]
            (Queue.to_list mock.received)
            [ fork_config_json ] ) )

(* A refusal is retried, up to max_tries. *)
let retries_a_refusal =
  run (fun () ->
      with_mock ~refuse:2 (fun mock ->
          let%map result =
            Mina_lib.Archive_client.dispatch_hardfork_config ~max_tries:3
              ~logger
              (Mock_archive.location mock)
              ~config_json:fork_config_json
          in
          Or_error.ok_exn result ;
          [%test_eq: int] !(mock.refusals) 2 ;
          [%test_eq: int] (Queue.length mock.received) 1 ) )

(* An archive that keeps refusing is reported, not retried for ever. *)
let gives_up_after_max_tries =
  run (fun () ->
      with_mock ~refuse:100 (fun mock ->
          let%map result =
            Mina_lib.Archive_client.dispatch_hardfork_config ~max_tries:2
              ~logger
              (Mock_archive.location mock)
              ~config_json:fork_config_json
          in
          [%test_eq: int] !(mock.refusals) 2 ;
          [%test_eq: int] (Queue.length mock.received) 0 ;
          match result with
          | Ok () ->
              failwith "a refusing archive was reported as success"
          | Error e ->
              let msg = Error.to_string_hum e in
              if not (String.is_substring msg ~substring:"after 2 tries") then
                failwithf "the error does not say how often it tried: %s" msg () ) )

(* No archive at all is an error, not a hang. *)
let reports_a_missing_archive =
  run (fun () ->
      let%bind port = Mina_automation.Utils.free_port () in
      let%map result =
        Mina_lib.Archive_client.dispatch_hardfork_config ~max_tries:1 ~logger
          { Cli_lib.Flag.Types.name = "--archive-address"
          ; value = Host_and_port.create ~host:"127.0.0.1" ~port
          }
          ~config_json:fork_config_json
      in
      if Result.is_ok result then
        failwith "sending to a port nobody listens on was reported as success" )

(* The daemon's own send: nothing without an archive address, and a failure is
   logged rather than raised -- the daemon must not stop for its archive. *)
let send_is_best_effort =
  run (fun () ->
      let%bind () =
        Init.Mina_run.send_hardfork_config_to_archive ~logger
          ~archive_location:None ~config_json:fork_config_json
      in
      let%bind () =
        with_mock ~refuse:100 (fun mock ->
            Init.Mina_run.send_hardfork_config_to_archive ~logger
              ~archive_location:(Some (Mock_archive.location mock))
              ~config_json:fork_config_json )
      in
      with_mock (fun mock ->
          let%map () =
            Init.Mina_run.send_hardfork_config_to_archive ~logger
              ~archive_location:(Some (Mock_archive.location mock))
              ~config_json:fork_config_json
          in
          [%test_eq: int] (Queue.length mock.received) 1 ) )

let runtime_config_of json =
  Yojson.Safe.from_string json
  |> Runtime_config.of_yojson |> Result.ok_or_failwith

(* The heartbeat repeats the daemon's runtime configuration while it runs, and
   sends nothing on a network that has not forked. *)
let heartbeat_repeats_on_a_forked_network =
  run (fun () ->
      let runtime_config = runtime_config_of fork_config_json in
      let expected =
        Runtime_config.to_yojson runtime_config |> Yojson.Safe.to_string
      in
      let%bind () =
        with_mock (fun mock ->
            let stop = Ivar.create () in
            let beating =
              Init.Mina_run.hardfork_config_heartbeat ~logger
                ~interval:(Time.Span.of_ms 100.) ~stop:(Ivar.read stop)
                ~archive_location:(Some (Mock_archive.location mock))
                runtime_config
            in
            let rec until_three () =
              if Queue.length mock.received >= 3 then Deferred.unit
              else
                let%bind () = after (Time.Span.of_ms 50.) in
                until_three ()
            in
            let%bind () =
              match%map
                Clock.with_timeout (Time.Span.of_sec 10.) (until_three ())
              with
              | `Result () ->
                  ()
              | `Timeout ->
                  failwithf "the heartbeat sent %d times in 10s, expected 3"
                    (Queue.length mock.received)
                    ()
            in
            Ivar.fill stop () ;
            let%map () = beating in
            Queue.iter mock.received ~f:(fun got ->
                [%test_eq: string] got expected ) )
      in
      with_mock (fun mock ->
          let%map () =
            Init.Mina_run.hardfork_config_heartbeat ~logger
              ~interval:(Time.Span.of_ms 100.)
              ~archive_location:(Some (Mock_archive.location mock))
              (runtime_config_of {json|{"proof":{}}|json})
          in
          [%test_eq: int] (Queue.length mock.received) 0 ) )

let tests =
  let open Alcotest in
  [ test_case "The daemon sends its config verbatim" `Quick
      delivers_the_config_verbatim
  ; test_case "A refusal is retried up to max_tries" `Quick retries_a_refusal
  ; test_case "A refusing archive is reported after max_tries" `Quick
      gives_up_after_max_tries
  ; test_case "A missing archive is reported" `Quick reports_a_missing_archive
  ; test_case "The daemon's send is best effort" `Quick send_is_best_effort
  ; test_case "The heartbeat repeats only on a forked network" `Quick
      heartbeat_repeats_on_a_forked_network
  ]
