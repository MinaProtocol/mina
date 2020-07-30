open Core
open Async
open Coda_base

type Structured_log_events.t +=
  | Merge_snark_generated of
      { time:
          (Time.Span.t[@to_yojson
                        fun total -> `String (Time.Span.to_string_hum total)]
                      [@of_yojson
                        function
                        | `String time ->
                            Ok (Time.Span.of_string time)
                        | _ ->
                            Error
                              "Snark_worker.Functor: Could not parse timespan"])
      }
  [@@deriving register_event {msg= "Merge SNARK generated in $time"}]

type Structured_log_events.t +=
  | Base_snark_generated of
      { time:
          (Time.Span.t[@to_yojson
                        fun total -> `String (Time.Span.to_string_hum total)]
                      [@of_yojson
                        function
                        | `String time ->
                            Ok (Time.Span.of_string time)
                        | _ ->
                            Error
                              "Snark_worker.Functor: Could not parse timespan"])
      }
  [@@deriving register_event {msg= "Base SNARK generated in $time"}]

module Make (Inputs : Intf.Inputs_intf) :
  Intf.S0 with type ledger_proof := Inputs.Ledger_proof.t = struct
  open Inputs
  module Rpcs = Rpcs.Make (Inputs)

  module Work = struct
    open Snark_work_lib

    module Single = struct
      module Spec = struct
        type t =
          ( Transaction.t
          , Transaction_witness.t
          , Ledger_proof.t )
          Work.Single.Spec.t
        [@@deriving sexp, to_yojson]
      end
    end

    module Spec = struct
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp, to_yojson]
    end

    module Result = struct
      type t = (Spec.t, Ledger_proof.t) Work.Result.t
    end
  end

  let perform (s : Worker_state.t) public_key
      ({instances; fee} as spec : Work.Spec.t) =
    One_or_two.Or_error.map instances ~f:(fun w ->
        let open Or_error.Let_syntax in
        let%map proof, time =
          perform_single s
            ~message:(Coda_base.Sok_message.create ~fee ~prover:public_key)
            w
        in
        ( proof
        , (time, match w with Transition _ -> `Transition | Merge _ -> `Merge)
        ) )
    |> Or_error.map ~f:(function
         | `One (proof1, metrics1) ->
             { Snark_work_lib.Work.Result.proofs= `One proof1
             ; metrics= `One metrics1
             ; spec
             ; prover= public_key }
         | `Two ((proof1, metrics1), (proof2, metrics2)) ->
             { Snark_work_lib.Work.Result.proofs= `Two (proof1, proof2)
             ; metrics= `Two (metrics1, metrics2)
             ; spec
             ; prover= public_key } )

  let dispatch rpc shutdown_on_disconnect query address =
    let%map res =
      Rpc.Connection.with_client ~handshake_timeout:(Time.Span.of_sec 60.0)
        ~heartbeat_config:
          (Rpc.Connection.Heartbeat_config.create
             ~timeout:(Time_ns.Span.of_sec 60.0)
             ~send_every:(Time_ns.Span.of_sec 10.0))
        (Tcp.Where_to_connect.of_host_and_port address)
        (fun conn -> Rpc.Rpc.dispatch rpc conn query)
    in
    match res with
    | Error exn ->
        if shutdown_on_disconnect then
          failwithf
            !"Shutting down. Error using the RPC call, %s,: %s"
            (Rpc.Rpc.name rpc) (Exn.to_string_mach exn) ()
        else
          Error
            ( Error.createf
                !"Error using the RPC call, %s: %s"
                (Rpc.Rpc.name rpc)
            @@ Exn.to_string_mach exn )
    | Ok res ->
        res

  let emit_proof_metrics metrics logger =
    One_or_two.iter metrics ~f:(fun (time, tag) ->
        match tag with
        | `Merge ->
            Coda_metrics.(
              Cryptography.Snark_work_histogram.observe
                Cryptography.snark_work_merge_time_sec (Time.Span.to_sec time)) ;
            Logger.Structured.info logger ~module_:__MODULE__ ~location:__LOC__
              (Merge_snark_generated {time})
        | `Transition ->
            Coda_metrics.(
              Cryptography.Snark_work_histogram.observe
                Cryptography.snark_work_base_time_sec (Time.Span.to_sec time)) ;
            Logger.Structured.info logger ~module_:__MODULE__ ~location:__LOC__
              (Base_snark_generated {time}) )

  let main
      (module Rpcs_versioned : Intf.Rpcs_versioned_S
        with type Work.ledger_proof = Inputs.Ledger_proof.t) ~logger
      ~proof_level ~constraint_constants daemon_address shutdown_on_disconnect
      =
    let%bind state =
      Worker_state.create ~proof_level ~constraint_constants ()
    in
    let wait ?(sec = 0.5) () = after (Time.Span.of_sec sec) in
    (* retry interval with jitter *)
    let retry_pause sec = Random.float_range (sec -. 2.0) (sec +. 2.0) in
    let log_and_retry label error sec k =
      let error_str = Error.to_string_hum error in
      (* HACK: the bind before the call to go () produces an evergrowing
           backtrace history which takes forever to print and fills our disks.
           If the string becomes too long, chop off the first 10 lines and include
           only that *)
      ( if String.length error_str < 4096 then
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          !"Error %s: %{sexp:Error.t}"
          label error
      else
        let lines = String.split ~on:'\n' error_str in
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          !"Error %s: %s" label
          (String.concat ~sep:"\\n" (List.take lines 10)) ) ;
      let%bind () = wait ~sec () in
      (* FIXME: Use a backoff algo here *)
      k ()
    in
    let rec go () =
      match%bind
        dispatch Rpcs_versioned.Get_work.Latest.rpc shutdown_on_disconnect ()
          daemon_address
      with
      | Error e ->
          log_and_retry "getting work" e (retry_pause 10.) go
      | Ok None ->
          let random_delay =
            Worker_state.worker_wait_time
            +. (0.5 *. Random.float Worker_state.worker_wait_time)
          in
          (* No work to be done -- quietly take a brief nap *)
          let%bind () = wait ~sec:random_delay () in
          go ()
      | Ok (Some (work, public_key)) -> (
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "SNARK work received from $address. Starting proof generation"
            ~metadata:
              [("address", `String (Host_and_port.to_string daemon_address))] ;
          let%bind () = wait () in
          (* Pause to wait for stdout to flush *)
          match perform state public_key work with
          | Error e ->
              log_and_retry "performing work" e (retry_pause 10.) go
          | Ok result ->
              emit_proof_metrics result.metrics logger ;
              Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                "Submitted completed SNARK work to $address"
                ~metadata:
                  [ ( "address"
                    , `String (Host_and_port.to_string daemon_address) ) ] ;
              let rec submit_work () =
                match%bind
                  dispatch Rpcs_versioned.Submit_work.Latest.rpc
                    shutdown_on_disconnect result daemon_address
                with
                | Error e ->
                    log_and_retry "submitting work" e (retry_pause 10.)
                      submit_work
                | Ok () ->
                    go ()
              in
              submit_work () )
    in
    go ()

  let command_from_rpcs
      (module Rpcs_versioned : Intf.Rpcs_versioned_S
        with type Work.ledger_proof = Inputs.Ledger_proof.t) =
    Command.async ~summary:"Snark worker"
      (let open Command.Let_syntax in
      let%map_open daemon_port =
        flag "daemon-address"
          (required (Arg_type.create Host_and_port.of_string))
          ~doc:"HOST-AND-PORT address daemon is listening on"
      and proof_level =
        flag "proof-level"
          (optional (Arg_type.create Genesis_constants.Proof_level.of_string))
          ~doc:"full|check|none"
      and shutdown_on_disconnect =
        flag "shutdown-on-disconnect" (optional bool)
          ~doc:
            "true|false Shutdown when disconnected from daemon (default:true)"
      in
      fun () ->
        let logger =
          Logger.create () ~metadata:[("process", `String "Snark Worker")]
        in
        Signal.handle [Signal.term] ~f:(fun _signal ->
            Logger.info logger
              !"Received signal to terminate. Aborting snark worker process"
              ~module_:__MODULE__ ~location:__LOC__ ;
            Core.exit 0 ) ;
        let proof_level =
          Option.value ~default:Genesis_constants.Proof_level.compiled
            proof_level
        in
        main
          (module Rpcs_versioned)
          ~logger ~proof_level
          ~constraint_constants:Genesis_constants.Constraint_constants.compiled
          daemon_port
          (Option.value ~default:true shutdown_on_disconnect))

  let arguments ~proof_level ~daemon_address ~shutdown_on_disconnect =
    [ "-daemon-address"
    ; Host_and_port.to_string daemon_address
    ; "-proof-level"
    ; Genesis_constants.Proof_level.to_string proof_level
    ; "-shutdown-on-disconnect"
    ; Bool.to_string shutdown_on_disconnect ]
end
