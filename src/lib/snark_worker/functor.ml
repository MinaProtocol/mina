open Core
open Async
open Coda_base

module Make (Inputs : Intf.Inputs_intf) :
  Intf.S with type ledger_proof := Inputs.Ledger_proof.t = struct
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
        [@@deriving sexp]
      end
    end

    module Spec = struct
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp]
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
      Rpc.Connection.with_client
        (Tcp.Where_to_connect.of_host_and_port address) (fun conn ->
          Rpc.Rpc.dispatch rpc conn query )
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
    One_or_two.iter metrics ~f:(fun (total, tag) ->
        match tag with
        | `Merge ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              "Merge SNARK generated in $time"
              ~metadata:[("time", `String (Time.Span.to_string_hum total))]
        | `Transition ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              "Base SNARK generated in $time"
              ~metadata:[("time", `String (Time.Span.to_string_hum total))] )

  let main ~logger daemon_address shutdown_on_disconnect =
    let%bind state = Worker_state.create () in
    let wait ?(sec = 0.5) () = after (Time.Span.of_sec sec) in
    let rec go () =
      let log_and_retry label error =
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          !"Error %s: %{sexp:Error.t}"
          label error ;
        let%bind () = wait ~sec:30.0 () in
        (* FIXME: Use a backoff algo here *)
        go ()
      in
      match%bind
        dispatch Rpcs.Get_work.Latest.rpc shutdown_on_disconnect ()
          daemon_address
      with
      | Error e ->
          log_and_retry "getting work" e
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
              log_and_retry "performing work" e
          | Ok result -> (
              match%bind
                emit_proof_metrics result.metrics logger ;
                Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                  "Submitted completed SNARK work to $address"
                  ~metadata:
                    [ ( "address"
                      , `String (Host_and_port.to_string daemon_address) ) ] ;
                dispatch Rpcs.Submit_work.Latest.rpc shutdown_on_disconnect
                  result daemon_address
              with
              | Error e ->
                  log_and_retry "submitting work" e
              | Ok () ->
                  go () ) )
    in
    go ()

  let command =
    Command.async ~summary:"Snark worker"
      (let open Command.Let_syntax in
      let%map_open daemon_port =
        flag "daemon-address"
          (required (Arg_type.create Host_and_port.of_string))
          ~doc:"HOST-AND-PORT address daemon is listening on"
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
        main ~logger daemon_port
          (Option.value ~default:true shutdown_on_disconnect))

  let arguments ~daemon_address ~shutdown_on_disconnect =
    [ "-daemon-address"
    ; Host_and_port.to_string daemon_address
    ; "-shutdown-on-disconnect"
    ; Bool.to_string shutdown_on_disconnect ]
end
