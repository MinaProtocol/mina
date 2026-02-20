open Utils

module Types : sig
  module type S = sig
    module Digest : V1S0
  end
end

module type Concrete = Types.S with type Digest.V1.t = string

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Digest = M.Digest
