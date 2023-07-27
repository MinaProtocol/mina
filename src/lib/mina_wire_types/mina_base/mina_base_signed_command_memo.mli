open Utils

module Types : sig
  module type S = V1S0
end

module type Concrete = Types.S with type V1.t = string

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V1 = M.V1
