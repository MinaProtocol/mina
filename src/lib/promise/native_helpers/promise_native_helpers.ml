(* there is no risk in doing Obj.magic here -- Promise.t is the same as Deferred.t in the native build *)

let to_deferred (promise : 'a Promise.t) : 'a Async_kernel.Deferred.t =
  Obj.magic promise

let of_deferred (deferred : 'a Async_kernel.Deferred.t) : 'a Promise.t =
  Obj.magic deferred
