open Core_kernel

let last_call_id = ref 0

module Call_tag = struct
  type t = string option [@@deriving sexp]

  let to_metadata t =
    Option.value_map ~default:[]
      ~f:(fun tag -> [ ("current_call_tag", `String tag) ])
      t
end

let key = Univ_map.Key.create ~name:"call_id" [%sexp_of: int * Call_tag.t]

let with_call_id ?tag f =
  incr last_call_id ;
  Async_kernel.Async_kernel_scheduler.with_local key
    (Some (!last_call_id, tag))
    ~f

let get_opt () = Async_kernel.Async_kernel_scheduler.find_local key

let get () = Option.value (get_opt ()) ~default:(0, None)
