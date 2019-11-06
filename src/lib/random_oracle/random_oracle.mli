module Input = Random_oracle_make.Input

module State : sig
  type 'a t [@@deriving eq, sexp, compare]

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

include
  Random_oracle_make.Intf.Full(Curve_choice.Tick_full.Field).S
  with module State := State
