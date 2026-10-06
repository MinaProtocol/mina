(* The daemon side of the hard fork announcement, against
   Mina_automation.Mock_archive: the daemon code under test --
   Archive_client.announce_hardfork and Mina_run's send and heartbeat -- runs
   unchanged over a real connection.

   No postgres and no archive process: these cases run anywhere.

   Run:
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test daemon_hardfork_rpc
*)

open Async
open Core
open Archive_lib.Hardfork_announcement

let logger = Logger.null ()

module Mock_archive = Mina_automation.Mock_archive

let with_mock = Mock_archive.with_mock

let fork_state_hash = "3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ"

(* The runtime config a daemon announces. *)
let fork_config_json =
  Mina_automation.Fork_runtime_config.naming ~state_hash:fork_state_hash
    ~height:10 ~slot:12 ()

let query ~side =
  query_of_config ~side ~protocol_version:Protocol_version.current
    ~config_json:fork_config_json
  |> Result.ok_or_failwith

let refusal =
  Reply.Refused
    (Refusal.Era_mismatch
       { announced = Protocol_version.current
       ; archive = Protocol_version.current
       } )

let run f () = Thread_safe.block_on_async_exn f

(* What the daemon sends is the fork it read from its config, its own protocol
   version, the side, and the config byte for byte. *)
let sends_the_announcement_verbatim =
  run (fun () ->
      with_mock (fun mock ->
          let%map reply =
            Mina_lib.Archive_client.announce_hardfork ~max_tries:1 ~logger
              (Mock_archive.location mock)
              (query ~side:Before_fork)
            >>| Or_error.ok_exn
          in
          [%test_eq: Reply.t] reply (Accepted Recorded) ;
          match Mock_archive.answered mock with
          | [ got ] ->
              [%test_eq: string] got.config_json fork_config_json ;
              [%test_eq: Side.t] got.side Before_fork ;
              [%test_eq: Protocol_version.t] got.protocol_version
                Protocol_version.current ;
              [%test_eq: string]
                (Mina_base.State_hash.to_base58_check got.fork_state_hash)
                fork_state_hash
          | answered ->
              failwithf "expected one announcement, got %d"
                (List.length answered) () ) )

(* A failed exchange is retried, up to max_tries. *)
let retries_a_failed_exchange =
  run (fun () ->
      with_mock ~fail_exchanges:2 (fun mock ->
          let%map reply =
            Mina_lib.Archive_client.announce_hardfork ~max_tries:3 ~logger
              (Mock_archive.location mock)
              (query ~side:Before_fork)
            >>| Or_error.ok_exn
          in
          [%test_eq: Reply.t] reply (Accepted Recorded) ;
          [%test_eq: int] (Mock_archive.failed_exchanges mock) 2 ;
          [%test_eq: int] (List.length (Mock_archive.answered mock)) 1 ) )

(* An archive that never answers is reported, not retried for ever. *)
let gives_up_after_max_tries =
  run (fun () ->
      with_mock ~fail_exchanges:100 (fun mock ->
          let%map result =
            Mina_lib.Archive_client.announce_hardfork ~max_tries:2 ~logger
              (Mock_archive.location mock)
              (query ~side:Before_fork)
          in
          [%test_eq: int] (Mock_archive.failed_exchanges mock) 2 ;
          match result with
          | Ok _ ->
              failwith "an archive that never answered was reported as one"
          | Error e ->
              let msg = Error.to_string_hum e in
              if not (String.is_substring msg ~substring:"after 2 tries") then
                failwithf "the error does not say how often it tried: %s" msg () ) )

(* A refusal is an answer: returned as it is, after one exchange. *)
let a_refusal_is_not_retried =
  run (fun () ->
      with_mock ~reply:refusal (fun mock ->
          let%map reply =
            Mina_lib.Archive_client.announce_hardfork ~max_tries:5 ~logger
              (Mock_archive.location mock)
              (query ~side:Before_fork)
            >>| Or_error.ok_exn
          in
          [%test_eq: Reply.t] reply refusal ;
          [%test_eq: int] (List.length (Mock_archive.answered mock)) 1 ) )

(* No archive at all is an error, not a hang. *)
let reports_a_missing_archive =
  run (fun () ->
      let%bind port = Mina_automation.Utils.free_port () in
      let%map result =
        Mina_lib.Archive_client.announce_hardfork ~max_tries:1 ~logger
          { Cli_lib.Flag.Types.name = "--archive-address"
          ; value = Host_and_port.create ~host:"127.0.0.1" ~port
          }
          (query ~side:Before_fork)
      in
      if Result.is_ok result then
        failwith "sending to a port nobody listens on was reported as success" )

(* The daemon's own send: nothing without an archive address, a refusal is
   returned rather than raised -- the daemon must not stop for its archive --
   and an accepted announcement arrives with the side asked for. *)
let send_is_best_effort =
  run (fun () ->
      let send archive_location =
        Init.Mina_run.send_hardfork_config_to_archive ~logger ~side:Before_fork
          ~archive_location ~config_json:fork_config_json
      in
      let%bind none = send None in
      [%test_eq: Reply.t option] none None ;
      let%bind () =
        with_mock ~reply:refusal (fun mock ->
            let%map reply = send (Some (Mock_archive.location mock)) in
            [%test_eq: Reply.t option] reply (Some refusal) )
      in
      with_mock (fun mock ->
          let%map reply = send (Some (Mock_archive.location mock)) in
          [%test_eq: Reply.t option] reply (Some (Accepted Recorded)) ;
          [%test_eq: Side.t list]
            (Mock_archive.answered mock |> List.map ~f:(fun q -> q.Query.side))
            [ Before_fork ] ) )

let runtime_config_of json =
  Yojson.Safe.from_string json
  |> Runtime_config.of_yojson |> Result.ok_or_failwith

let until ~timeout ~what condition =
  let rec poll () =
    if condition () then Deferred.unit
    else
      let%bind () = after (Time.Span.of_ms 50.) in
      poll ()
  in
  match%map Clock.with_timeout timeout (poll ()) with
  | `Result () ->
      ()
  | `Timeout ->
      failwithf "timed out waiting for %s" what ()

(* The heartbeat re-sends the fork that started the daemon's era, from the
   other side of it; it stops at a refusal and sends nothing on a network that
   has not forked. *)
let heartbeat_resends_after_the_fork =
  run (fun () ->
      let runtime_config = runtime_config_of fork_config_json in
      let expected =
        Runtime_config.to_yojson runtime_config |> Yojson.Safe.to_string
      in
      let beat ?stop mock config =
        Init.Mina_run.hardfork_config_heartbeat ~logger
          ~interval:(Time.Span.of_ms 100.) ?stop
          ~archive_location:(Some (Mock_archive.location mock))
          config
      in
      let%bind () =
        with_mock ~reply:(Accepted Era_start) (fun mock ->
            let stop = Ivar.create () in
            let beating = beat ~stop:(Ivar.read stop) mock runtime_config in
            let%bind () =
              until ~timeout:(Time.Span.of_sec 10.) ~what:"three heartbeats"
                (fun () -> List.length (Mock_archive.answered mock) >= 3)
            in
            Ivar.fill stop () ;
            let%map () = beating in
            List.iter (Mock_archive.answered mock) ~f:(fun q ->
                [%test_eq: string] q.config_json expected ;
                [%test_eq: Side.t] q.side After_fork ) )
      in
      let%bind () =
        with_mock ~reply:refusal (fun mock ->
            (* Returns by itself: a refused heartbeat is not repeated. *)
            let%map () = beat mock runtime_config in
            [%test_eq: int] (List.length (Mock_archive.answered mock)) 1 )
      in
      with_mock (fun mock ->
          let%map () =
            beat mock
              (runtime_config_of
                 (Mina_automation.Fork_runtime_config.without_fork ()) )
          in
          [%test_eq: int] (List.length (Mock_archive.answered mock)) 0 ) )

let tests =
  let open Alcotest in
  [ test_case "The daemon sends its announcement verbatim" `Quick
      sends_the_announcement_verbatim
  ; test_case "A failed exchange is retried up to max_tries" `Quick
      retries_a_failed_exchange
  ; test_case "An archive that never answers is reported after max_tries" `Quick
      gives_up_after_max_tries
  ; test_case "A refusal is an answer and is not retried" `Quick
      a_refusal_is_not_retried
  ; test_case "A missing archive is reported" `Quick reports_a_missing_archive
  ; test_case "The daemon's send is best effort" `Quick send_is_best_effort
  ; test_case "The heartbeat re-sends after the fork and stops at a refusal"
      `Quick heartbeat_resends_after_the_fork
  ]
