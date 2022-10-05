open Utils

(** We follow the same structure from {i currency.ml} *)

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

(** Here, we {b hide} the concrete type definitions from our module, which is
    the whole point of all this machinery. *)
module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

(** Finally, we expose only the types from {!Types.S} but we clarify that the
    types here are the same that those from {!M}. In some cases this is
    equivalent to [include M]. *)
include
  Types.S
    with module Fee = M.Fee
     and module Amount = M.Amount
     and module Balance = M.Balance
