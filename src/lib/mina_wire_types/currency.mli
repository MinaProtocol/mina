open Utils

module Types : sig
  module type S = sig
    module Fee : V1S0

    module Amount : V1S0

    module Balance : V1S0
  end
end

module type Concrete =
  Types.S
    with type Fee.V1.t = Unsigned.UInt64.t
     and type Amount.V1.t = Unsigned.UInt64.t
     and type Balance.V1.t = Unsigned.UInt64.t

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S
    with module Fee = M.Fee
     and module Amount = M.Amount
     and module Balance = M.Balance
