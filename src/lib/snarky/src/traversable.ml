open Core_kernel

module type S = sig
  type 'a t

  (* TODO-someday: Should be applicative, it's anonying because Applicative.S is not a subsignature
   of Monad.S, but Monad.S is more common so we go with that. *)
  module Traverse (A : Monad.S) : sig
    val f : 'a t -> f:('a -> 'b A.t) -> 'b t A.t
  end
end
