module Params = Params

module State : sig
  type 'a t = 'a array

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Rescue (Inputs : Intf.Inputs.Rescue) :
  Intf.Permutation with module Field = Inputs.Field

module Poseidon (Inputs : Intf.Inputs.Common) :
  Intf.Permutation with module Field = Inputs.Field

module Make_operations (Field : Intf.Field) :
  Intf.Operations with module Field := Field

module Make (P : Intf.Permutation) : sig
  open P

  val update :
       Field.t Params.t
    -> state:Field.t State.t
    -> Field.t array
    -> Field.t State.t

  val digest : Field.t State.t -> Field.t

  val initial_state : Field.t State.t

  val hash :
    ?init:Field.t State.t -> Field.t Params.t -> Field.t array -> Field.t
end
