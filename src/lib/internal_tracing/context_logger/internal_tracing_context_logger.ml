open Core_kernel

let key = Univ_map.Key.create ~name:"logger" sexp_of_opaque

let with_logger logger f =
  Async_kernel.Async_kernel_scheduler.with_local key logger ~f

let get_opt () = Async_kernel.Async_kernel_scheduler.find_local key

let get () = Option.value (get_opt ()) ~default:(Logger.null ())
