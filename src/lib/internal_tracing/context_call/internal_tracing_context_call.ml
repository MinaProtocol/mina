open Core_kernel

let last_call_id = ref 0

let key = Univ_map.Key.create ~name:"call_id" sexp_of_int

let with_call_id f =
  incr last_call_id ;
  Async_kernel.Async_kernel_scheduler.with_local key (Some !last_call_id) ~f

let get_opt () = Async_kernel.Async_kernel_scheduler.find_local key

let get () = Option.value (get_opt ()) ~default:0
