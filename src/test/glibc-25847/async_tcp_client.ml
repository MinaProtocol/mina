open! Core
open! Async

let n_clients =
  Option.value_map (Sys.getenv "N_CLIENT_FIBERS") ~default:16 ~f:Int.of_string

let port =
  match Sys.get_argv () with
  | [| _; p |] ->
      Int.of_string p
  | _ -> (
      match Sys.getenv "PORT" with
      | Some p ->
          Int.of_string p
      | None ->
          Core.eprintf "Usage: %s <port>  (or set PORT env var)\n"
            (Sys.get_argv ()).(0) ;
          Stdlib.exit 1 )

(* Client fiber: repeatedly connect, send, receive, disconnect *)
let client_fiber port =
  let where =
    Tcp.Where_to_connect.of_host_and_port
      (Host_and_port.create ~host:"127.0.0.1" ~port)
  in
  Deferred.forever () (fun () ->
      match%map
        try_with (fun () ->
            Tcp.with_connection where (fun _sock reader writer ->
                Writer.write_line writer "ping" ;
                let%bind () = Writer.flushed writer in
                let%map _ = Reader.read_line reader in
                () ) )
      with
      | Ok () ->
          ()
      | Error _ ->
          (* Connection errors expected occasionally under high churn *)
          () )

let () =
  don't_wait_for
    ( Core.printf "Async TCP client for glibc #25847 reproducer\n" ;
      Core.printf "Connecting to port %d with %d client fibers\n%!" port
        n_clients ;
      for _ = 1 to n_clients do
        client_fiber port
      done ;
      Deferred.never () ) ;
  never_returns (Scheduler.go ())
