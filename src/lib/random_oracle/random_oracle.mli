open Crypto_params.Tick0
module Input = Input

module State : sig
  type 'a t [@@deriving eq, sexp, compare]

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

include
  Intf.S
  with type field := Field.t
   and type field_constant := Field.t
   and type bool := bool
   and module State := State

module Checked :
  Intf.S
  with type field := Field.Var.t
   and type field_constant := Field.t
   and type bool := Boolean.var
   and module State := State
