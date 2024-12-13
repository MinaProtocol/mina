open Async_kernel

module type S = sig
  type t

  type msg

  type cache_proof_db

  val push : t -> msg -> cache_proof_db -> unit Deferred.t
end

module type S_with_void = sig
  include S

  val void : t
end
