open Core
open Async

module Make (Inputs : Intf.Inputs_intf) :
  Intf.S
  with type transition := Inputs.Super_transaction.t
   and type sparse_ledger := Inputs.Sparse_ledger.t
   and type statement := Inputs.Statement.t
   and type proof := Inputs.Proof.t = struct
  open Inputs

  module Work = struct
    open Snark_work_lib

    module Single = struct
      module Spec = struct
        type t =
          ( Statement.t
          , Super_transaction.t
          , Sparse_ledger.t
          , Proof.t )
          Work.Single.Spec.t
        [@@deriving sexp]
      end
    end

    module Spec = struct
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp]
    end

    module Result = struct
      type t = (Spec.t, Proof.t) Work.Result.t
    end
  end

  module Rpcs = Rpcs.Make (Inputs)

  let perform (s : Worker_state.t) public_key
      ({instances; fee} as spec : Work.Spec.t) =
    List.fold_until instances ~init:([], [])
      ~f:(fun (acc1, acc2) w ->
        match
          perform_single s
            ~message:(Coda_base.Sok_message.create ~fee ~prover:public_key)
            w
        with
        | Ok (res, time) ->
            let tag =
              match w with
              | Snark_work_lib.Work.Single.Spec.Transition _ -> `Transition
              | Merge _ -> `Merge
            in
            Continue (res :: acc1, (time, tag) :: acc2)
        | Error e -> Stop (Error e) )
      ~finish:(fun (res, metrics) ->
        Ok
          { Snark_work_lib.Work.Result.proofs= List.rev res
          ; metrics= List.rev metrics
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
          failwithf !"Shutting down. Error: %s" (Exn.to_string_mach exn) ()
        else Or_error.of_exn exn
    | Ok res -> res

  let main daemon_address public_key shutdown_on_disconnect =
    let log = Logger.create () in
    let%bind state = Worker_state.create () in
    let wait ?(sec = 0.5) () = after (Time.Span.of_sec sec) in
    let rec go () =
      let log_and_retry label error =
        Logger.error log !"Error %s:\n%{sexp:Error.t}" label error ;
        let%bind () = wait () in
        go ()
      in
      Logger.info log "Asking for work again..." ;
      match%bind
        dispatch Rpcs.Get_work.rpc shutdown_on_disconnect () daemon_address
      with
      | Error e -> log_and_retry "getting work" e
      | Ok None ->
          Logger.info log "No work; waiting a few seconds before retrying" ;
          let%bind () = wait ~sec:Worker_state.worker_wait_time () in
          go ()
      | Ok (Some work) -> (
          Logger.info log "Got some work\n" ;
          match perform state public_key work with
          | Error e -> log_and_retry "performing work" e
          | Ok result -> (
              match%bind
                dispatch Rpcs.Submit_work.rpc shutdown_on_disconnect result
                  daemon_address
              with
              | Error e -> log_and_retry "submitting work" e
              | Ok () -> go () ) )
    in
    go ()

  let command =
    Command.async ~summary:"Snark worker"
      (let open Command.Let_syntax in
      let%map_open daemon_port =
        flag "daemon-address"
          (required (Arg_type.create Host_and_port.of_string))
          ~doc:"HOST-AND-PORT address daemon is listening on"
      and public_key =
        flag "public-key"
          (required Cli_lib.public_key_compressed)
          ~doc:"PUBLICKEY Public key to send SNARKing fees to"
      and shutdown_on_disconnect =
        flag "shutdown-on-disconnect" (optional bool)
          ~doc:
            "true|false Shutdown when disconnected from daemon (default:true)"
      in
      fun () ->
        main daemon_port public_key
          (Option.value ~default:true shutdown_on_disconnect))

  let arguments ~public_key ~daemon_address ~shutdown_on_disconnect =
    [ "-public-key"
    ; Signature_lib.Public_key.Compressed.to_base64 public_key
    ; "-daemon-address"
    ; Host_and_port.to_string daemon_address
    ; "-shutdown-on-disconnect"
    ; Bool.to_string shutdown_on_disconnect ]
end
