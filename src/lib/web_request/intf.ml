open Async_kernel

module type S = sig
  type t

  val create : unit -> t Deferred.Or_error.t

  val put : t -> string -> unit Deferred.Or_error.t
end
