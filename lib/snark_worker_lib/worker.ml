open Core
open Async
open Blockchain_snark

module State = struct
  module type S = Transaction_snark.S

  type t = (module S)

  let create () =
    let open Async in
    let%map keys = Snark_keys.transaction () in
    ( module Transaction_snark.Make (struct
      let keys = keys
    end)
    : S )
end

let perform ((module M): State.t) : Work.Spec.t -> Work.Result.t Or_error.t =
  let open Or_error.Let_syntax in
  function
    | Transition (input, t, l) ->
        return
          (M.of_transition input.source input.target t
            (unstage (Ledger.handler l)))
    | Merge (proof1, proof2) ->
        M.merge proof1 proof2

let main daemon_port =
  let%bind conn =
    Rpc.Connection.client
      (Tcp.Where_to_connect.of_host_and_port
         (Host_and_port.create ~host:"127.0.0.1" ~port:daemon_port))
    >>| Result.ok_exn
  in
  let log = Logger.create () in
  let%bind state = State.create () in
  let wait ?(sec= 0.5) () = after (Time.Span.of_sec sec) in
  let rec go () =
    let log_and_retry label error =
      Logger.error log !"Error %s:\n%{sexp:Error.t}" label error ;
      let%bind () = wait () in
      go ()
    in
    match%bind Rpc.Rpc.dispatch Rpcs.Get_work.rpc conn () with
    | Error e -> log_and_retry "getting work" e
    | Ok work ->
      match perform state work with
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
    in
    fun () -> main daemon_port)
