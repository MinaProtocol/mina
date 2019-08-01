open Core
open Default_backend.Backend

type variable = A of int | B of int | C of int

module Coeff = struct
  type t = Zero | One | NegativeOne | Full of Fr.t

  let multiply a b =
    match a with
    | Zero ->
        Fr.zero
    | One ->
        b
    | NegativeOne ->
        Fr.negate b
    | Full v ->
        Fr.( * ) v b
end

module Linear_combination = struct
  type t = (variable * Coeff.t) array
end

(* "Backend" in Sean's code *)
module type Circuit_info = sig
  module Linear_constraint_index : sig
    type t
  end

  type t

  val get_var : t -> variable -> Fr.t

  val set_var : t -> variable -> (unit -> Fr.t) -> unit

  val new_multiplication_gate : t -> unit

  val new_linear_constraint : t -> Linear_constraint_index.t

  val insert_coefficient :
    t -> variable -> Coeff.t -> Linear_constraint_index.t -> unit

  val get_for_q : t -> int -> Linear_constraint_index.t

  val new_k_power : t -> int -> unit
end

module Synthesizer (Circuit_info_impl : Circuit_info) = struct
  type t =
    { circuit_info: Circuit_info_impl.t
    ; current_variable: int option ref
    ; q: int ref
    ; n: int ref
    ; a: (Fr.t * int) option list array
    ; b: (Fr.t * int) option list array
    ; c: (Fr.t * int) option list array }

  let alloc (synth : t) (value : unit -> Fr.t) =
    match !(synth.current_variable) with
    | Some index ->
        let var_a = A index in
        let var_b = B index in
        let var_c = C index in
        let product = ref Fr.zero in
        let value_a = Circuit_info_impl.get_var synth.circuit_info var_a in
        let get_value_b () =
          let value_b = value () in
          product := Fr.( * ) value_a value_b ;
          value_b
        in
        Circuit_info_impl.set_var synth.circuit_info var_b get_value_b ;
        Circuit_info_impl.set_var synth.circuit_info var_c (fun () -> !product) ;
        synth.current_variable := None ;
        var_b
    | None ->
        synth.n := !(synth.n) + 1 ;
        let index = !(synth.n) in
        Circuit_info_impl.new_multiplication_gate synth.circuit_info ;
        let var_a = A index in
        Circuit_info_impl.set_var synth.circuit_info var_a value ;
        synth.current_variable := Some index ;
        var_a

  let alloc_input (synth : t) (value : unit -> Fr.t) =
    let input_var = alloc synth value in
    enforce_zero synth ()
end
