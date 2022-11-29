[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

open Pickles.Impls.Step.Internal_Basic

[%%else]

open Snark_params.Tick

[%%endif]

module Input = Random_oracle_input

module State : sig
  type 'a t [@@deriving equal, sexp, compare]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

include
  Intf.S
    with type field := Field.t
     and type field_constant := Field.t
     and type bool := bool
     and module State := State
     and type input := Field.t Random_oracle_input.Chunked.t

val salt : string -> Field.t State.t

[%%ifdef consensus_mechanism]

module Checked :
  Intf.S
    with type field := Field.Var.t
     and type field_constant := Field.t
     and type bool := Boolean.var
     and module State := State
     and type input := Field.Var.t Random_oracle_input.Chunked.t

(** Read a value stored within a circuit. Must only be used in an [As_prover]
    block.
*)
val read_typ : Field.Var.t Input.Chunked.t -> Field.t Input.Chunked.t

(** Read a value stored within a circuit. *)
val read_typ' :
     Field.Var.t Input.Chunked.t
  -> Field.t Input.Chunked.t Pickles.Impls.Step.Internal_Basic.As_prover.t

[%%endif]

module Legacy : sig
  module Input = Random_oracle_input.Legacy

  module State : sig
    type 'a t [@@deriving equal, sexp, compare]

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
  end

  include
    Intf.S
      with type field := Field.t
       and type field_constant := Field.t
       and type bool := bool
       and module State := State
       and type input := (Field.t, bool) Random_oracle_input.Legacy.t

  val salt : string -> Field.t State.t

  [%%ifdef consensus_mechanism]

  module Checked :
    Intf.S
      with type field := Field.Var.t
       and type field_constant := Field.t
       and type bool := Boolean.var
       and module State := State
       and type input := (Field.Var.t, Boolean.var) Random_oracle_input.Legacy.t

  [%%endif]
end
