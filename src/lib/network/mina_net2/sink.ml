open Async_kernel

module type S = sig
  type t

  type msg

  val push : t -> msg -> unit Deferred.t
end

module type S_with_void = sig
  include S

  val void : t
end
