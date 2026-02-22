open Utils

module Types : sig
  module type S = V2S0
end

module type Concrete = sig
  module V2 : sig
    type t = { transaction : int; network : int; patch : int }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with type V2.t = M.V2.t
