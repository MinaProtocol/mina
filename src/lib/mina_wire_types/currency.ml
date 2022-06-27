open Utils

module Types = struct
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

module M = struct
  type fee = Unsigned.UInt64.t

  type amount = Unsigned.UInt64.t

  type balance = amount
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
