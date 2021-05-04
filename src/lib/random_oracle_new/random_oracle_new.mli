[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

open Pickles.Impls.Step.Internal_Basic

[%%else]

open Snark_params_nonconsensus

[%%endif]

(*
module Input = Random_oracle_input

module State : sig
  type 'a t [@@deriving eq, sexp, compare]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

*)

include
  Random_oracle_to_extract.Intf.S
  with type field := Field.t
   and type field_constant := Field.t
   and type boolean := bool
   and module State := Random_oracle_to_extract.State

val salt : string -> Field.t Random_oracle_to_extract.State.t

[%%ifdef consensus_mechanism]

module Checked :
  Random_oracle_to_extract.Intf.S
  with type field := Field.Var.t
   and type field_constant := Field.t
   and type boolean := Boolean.var
   and module State := Random_oracle_to_extract.State

[%%endif]
