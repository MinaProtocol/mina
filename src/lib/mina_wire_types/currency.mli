open Utils

module Types : sig
  module type S = sig
    type fee

    type amount

    type balance
  end
end

module type Concrete =
  Types.S
    with type fee = Unsigned.UInt64.t
     and type amount = Unsigned.UInt64.t
     and type balance = Unsigned.UInt64.t

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S
