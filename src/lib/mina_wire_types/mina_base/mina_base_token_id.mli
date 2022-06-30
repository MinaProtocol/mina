open Utils

module Types : sig
  module type S = S0
end

module type Concrete = Types.S with type t = Unsigned.UInt64.t

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with type t = M.t
