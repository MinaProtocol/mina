(*********************************
 * Instantiate snarky for Vesta. *
 *********************************)

module Impl = Snarky_backendless.Snark.Run.Make (struct
  include Kimchi_backend.Pasta.Vesta_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end)

(* you can read the interface of Impl in Snark_intf.Run *)

(********************************
 * Helpers                      *
 ********************************)

(** Compiles the circuit. *)
let compile ~input_typ circuit : Impl.R1CS_constraint_system.t =
  Impl.constraint_system ~input_typ ~return_typ:Impl.Typ.unit circuit

(** Generates the witness for the circuit (doesn't need to be compiled) *)
let generate_witness ~(input_typ : ('var, _) Impl.Typ.t) ~input_val
    (circuit : 'var -> unit -> unit) : Impl.Proof_inputs.t =
  (* compiles the circuit *)
  let compiled =
    Impl.generate_witness ~input_typ ~return_typ:Impl.Typ.unit circuit
  in
  (* runs it with input *)
  compiled input_val

(** Serialies the circuit to JSON. *)
let serialize compiled_circuit : string =
  Kimchi_backend.Pasta.Vesta_based_plonk.R1CS_constraint_system.to_json
    compiled_circuit

(********************************
 * Exercise 1: input + 1 == 2.  *
 ********************************)

let circuit1 input _ : unit (* no output *) =
  failwith "you need to implement the circuit for exercise 1"

(* check if it compiles and runs *)
let () =
  let input_val = Impl.Field.Constant.of_int 1 in
  let (_ : Impl.Proof_inputs.t) =
    generate_witness ~input_typ:Impl.Typ.field ~input_val circuit1
  in
  ()

(* check serialization *)
let () =
  let compiled = compile ~input_typ:Impl.Typ.field circuit1 in
  let serialized = serialize compiled in
  Format.printf "%s@." serialized
