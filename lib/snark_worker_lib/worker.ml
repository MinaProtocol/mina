open Core
open Async
open Blockchain_snark

module Make (Inputs : Intf.Inputs_intf) :
  Intf.S
  with type transition := Inputs.Super_transaction.t
   and type sparse_ledger := Inputs.Sparse_ledger.t
   and type public_key := Inputs.Public_key.t
   and type statement := Inputs.Statement.t
   and type proof := Inputs.Proof.t =
struct
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
      end
    end

    module Spec = struct
      type t = Single.Spec.t Work.Spec.t
    end

    module Result = struct
      type t = (Spec.t, Proof.t) Work.Result.t
    end
  end

  module Rpcs = Rpcs.Make (Inputs)

  let perform (s: Worker_state.t) public_key
      ({instances; fee} as spec: Work.Spec.t) =
    List.fold_until instances ~init:[]
      ~f:(fun acc w ->
        match perform_single s ~message:(fee, public_key) w with
        | Ok res -> Continue (res :: acc)
        | Error e -> Stop (Error e) )
      ~finish:(fun res ->
        Ok {Snark_work_lib.Work.Result.proofs= List.rev res; spec} )

  let shutdown_on_disconnect log connection =
    upon (Rpc.Connection.close_finished connection) (fun () ->
        Logger.info log "Connection to daemon closed, shutting down." ;
        Shutdown.shutdown 0 )

  let main daemon_port public_key =
    let%bind conn =
      Rpc.Connection.client
        (Tcp.Where_to_connect.of_host_and_port
           (Host_and_port.create ~host:"127.0.0.1" ~port:daemon_port))
      >>| Result.ok_exn
    in
    let log = Logger.create () in
    shutdown_on_disconnect log conn ;
    let%bind state = Worker_state.create () in
    let wait ?(sec= 0.5) () = after (Time.Span.of_sec sec) in
    let rec go () =
      let log_and_retry label error =
        Logger.error log !"Error %s:\n%{sexp:Error.t}" label error ;
        let%bind () = wait () in
        go ()
      in
      match%bind Rpc.Rpc.dispatch Rpcs.Get_work.rpc conn () with
      | Error e -> log_and_retry "getting work" e
      | Ok None ->
          Logger.info log "No work; waiting a few seconds before retrying" ;
          let%bind () = wait ~sec:5. () in
          go ()
      | Ok (Some work) ->
        match perform state public_key work with
        | Error e -> log_and_retry "performing work" e
        | Ok result ->
          match Rpc.One_way.dispatch Rpcs.Submit_work.rpc conn result with
          | Error e -> log_and_retry "submitting work" e
          | Ok () ->
              let%bind () = wait ~sec:0.1 () in
              go ()
    in
    go ()

  let command =
    Command.async ~summary:"Snark worker"
      (let open Command.Let_syntax in
      let%map_open daemon_port =
        flag "daemon-port" (required int)
          ~doc:"port daemon is listening on locally"
      and public_key =
        flag "public-key"
          (required Public_key.arg_type)
          ~doc:"Public key to send SNARKing fees to"
      in
      fun () -> main daemon_port public_key)

  let arguments ~public_key ~daemon_port =
    [ "-public-key"
    ; Cli_lib.base64_of_binable (module Public_key) public_key
    ; "-daemon-port"
    ; Int.to_string daemon_port ]
end
