(* itn_logger.ml -- bounded queue of `internal` logs *)

open Core_kernel

type t =
  { sequence_no : int
  ; timestamp : string
  ; message : string
  ; metadata : (string * Yojson.Basic.t) list
  }

let log_queue : t Queue.t = Queue.create ()

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

let log ~timestamp ~message ~metadata =
  (* convert JSON to Basic.t in queue, so we don't have to in GraphQL response *)
  let metadata =
    List.map metadata ~f:(fun (s, json) -> (s, Yojson.Safe.to_basic json))
  in
  let t =
    { sequence_no = get_counter ()
    ; timestamp = Time.to_string_abs timestamp ~zone:Time.Zone.utc
    ; message
    ; metadata
    }
  in
  Queue.enqueue log_queue t ;
  if Queue.length log_queue > get_queue_bound () then
    ignore (Queue.dequeue_exn log_queue) ;
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
