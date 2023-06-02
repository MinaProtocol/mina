open Core_kernel

(* Keep a single definition of the FSM type here, so that it can be easily
   changed later, when new requirements present themselves. Keep the type
   abstract so that we don't rely on implementation details anywhere. *)
include Or_error

let fail (error : string) =
  Or_error.error_string error

let fail_unless ~error condition =
  if condition then Ok () else Or_error.error_string error

let to_result a = a
