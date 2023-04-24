(* itn_logger.ml -- bounded queue of `internal` logs *)

[%%import "/src/config.mlh"]

open Core_kernel

(* `itn_features` is available in Mina_compile_config
   using that module here introduces a cycle
*)
[%%inject "itn_features", itn_features]

[%%if itn_features]

(* queue of sequence no, message, metadata *)
let log_queue : (int * string * (string * Yojson.Basic.t) list) Queue.t =
  Queue.create ()

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

let log ~message ~metadata =
  (* convert JSON to Basic.t in queue, so we don't have to in GraphQL response *)
  let metadata_basic =
    List.map metadata ~f:(fun (s, json) -> (s, Yojson.Safe.to_basic json))
  in
  Queue.enqueue log_queue (get_counter (), message, metadata_basic) ;
  if Queue.length log_queue > get_queue_bound () then
    ignore (Queue.dequeue_exn log_queue) ;
  incr_counter ()

let get_logs start_log_id =
  let filtered_queue =
    Queue.filter log_queue ~f:(fun (n, _msg, _metadata) -> n >= start_log_id)
  in
  Queue.to_list filtered_queue

let flush_queue end_log_counter =
  (* remove items with counter less than or equal to end_log_counter *)
  let len = Queue.length log_queue in
  Queue.filter_inplace log_queue ~f:(fun (n, _msg, _metadata) ->
      n > end_log_counter ) ;
  let len' = Queue.length log_queue in
  len - len'

[%%else]

let set_queue_bound _ = failwith "Not implemented"

let log ~module_:_ ~location:_ ~message:_ ~metadata:_ = ()

[%%endif]
