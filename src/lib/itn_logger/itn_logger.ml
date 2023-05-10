(* itn_logger.ml -- bounded queue of `internal` logs *)

open Core

type t =
  { sequence_no : int
  ; timestamp : string
  ; message : string
  ; metadata : (string * Yojson.Basic.t) list
  ; process : string option
  }

(* log received from verifier or prover *)
type remote_log =
  { timestamp : Time.t
  ; message : string
  ; metadata : (string * string) list
  ; process : string
  }
[@@deriving bin_io_unversioned]

let log_queue : t Queue.t = Queue.create ()

let get_process_kind, set_process_kind =
  (* updated by prover or verifier
     it would be nice to use `process_kind`, but
     that introduces a cycle
  *)
  let process_kind : string option ref = ref None in
  let get () = !process_kind in
  let set kind = process_kind := Some kind in
  (get, set)

let get_queue_bound, set_queue_bound =
  let queue_bound = ref 500 in
  let get () = !queue_bound in
  let set n = queue_bound := n in
  (get, set)

let get_counter, incr_counter =
  let log_counter = ref 1 in
  let get () = !log_counter in
  let incr () = incr log_counter in
  (get, incr)

let daemon_where_to_connect, set_daemon_port =
  let mk_where port =
    Async.Tcp.Where_to_connect.of_host_and_port
      (Host_and_port.create ~host:"127.0.0.1" ~port)
  in
  let where = ref None in
  let set port = where := Some (mk_where port) in
  let get_where () = !where in
  (get_where, set)

let set_data ~process_kind ~daemon_port =
  set_process_kind process_kind ;
  set_daemon_port daemon_port

module Submit_internal_log = struct
  type query = remote_log [@@deriving bin_io_unversioned]

  type response = unit [@@deriving bin_io_unversioned]

  let rpc : (query, response) Async.Rpc.Rpc.t =
    Async.Rpc.Rpc.create ~name:"Submit_internal_log" ~version:0 ~bin_query
      ~bin_response
end

let dispatch_remote_log log =
  let open Async.Deferred.Let_syntax in
  let rpc = Submit_internal_log.rpc in
  match daemon_where_to_connect () with
  | None ->
      (* daemon port is set just after verifier, prover are created
         so should never happen
      *)
      eprintf "No daemon port set for ITN logger" ;
      Async.Deferred.unit
  | Some where_to_connect -> (
      let%map res =
        Async.Rpc.Connection.with_client
          ~handshake_timeout:
            (Time.Span.of_sec Mina_compile_config.rpc_handshake_timeout_sec)
          ~heartbeat_config:
            (Async.Rpc.Connection.Heartbeat_config.create
               ~timeout:
                 (Time_ns.Span.of_sec
                    Mina_compile_config.rpc_heartbeat_timeout_sec )
               ~send_every:
                 (Time_ns.Span.of_sec
                    Mina_compile_config.rpc_heartbeat_send_every_sec )
               () )
          where_to_connect
          (fun conn -> Async.Rpc.Rpc.dispatch rpc conn log)
      in
      (* not ideal that errors are not themselves logged *)
      match res with
      | Ok (Ok ()) ->
          ()
      | Ok (Error err) ->
          eprintf "Error sending internal log via RPC: %s"
            (Error.to_string_mach err)
      | Error exn ->
          eprintf "Exception when sending internal log via RPC: %s"
            (Exn.to_string_mach exn) )


(* Used to ensure that no more than one log message is on-flight at
   a time to guarantee sequential processing. *)
let sequential_dispatcher_loop () =
  let open Async in
  let pipe_r, pipe_w = Pipe.create () in
  don't_wait_for (Pipe.iter pipe_r ~f:dispatch_remote_log) ;
  pipe_w

let sequential_log_writer_pipe = sequential_dispatcher_loop ()

(* this function can be called:
   (1) by the logging process (daemon, verifier, or prover) from the logger in Logger, or
   (2) by the daemon when it receives a log via RPC from the verifier or prover

   for (1), if the process is the verifier or prover, the log is forwarded by RPC
    to the daemon, resulting in a recursive call of type (2)
*)
let log ?process ~timestamp ~message ~metadata () =
  match get_process_kind () with
  | Some process ->
      (* prover or verifier, send log to daemon

         we can't Bin_prot-serialize JSON, so make it a string
      *)
      let metadata =
        List.map metadata ~f:(fun (s, json) -> (s, Yojson.Safe.to_string json))
      in
      let remote_log = { timestamp; message; metadata; process } in
      (* write the message to the pipe *)
      Async.Pipe.write_without_pushback sequential_log_writer_pipe remote_log
  | None ->
      (* daemon *)
      (* convert JSON to Basic.t in queue, so we don't have to in GraphQL response *)
      let metadata =
        List.map metadata ~f:(fun (s, json) -> (s, Yojson.Safe.to_basic json))
      in
      let t =
        { sequence_no = get_counter ()
        ; timestamp = Time.to_string_abs timestamp ~zone:Time.Zone.utc
        ; message
        ; metadata
        ; process
        }
      in
      Queue.enqueue log_queue t ;
      if Queue.length log_queue > get_queue_bound () then
        ignore (Queue.dequeue_exn log_queue : t) ;
      incr_counter ()

let get_logs start_log_id =
  let filtered_queue =
    Queue.filter log_queue ~f:(fun t -> t.sequence_no >= start_log_id)
  in
  Queue.to_list filtered_queue

let flush_queue end_log_counter =
  (* remove items with counter less than or equal to end_log_counter *)
  let len = Queue.length log_queue in
  Queue.filter_inplace log_queue ~f:(fun t -> t.sequence_no > end_log_counter) ;
  let len' = Queue.length log_queue in
  len - len'
