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
  let one = Impl.constant Impl.Field.typ (Impl.Field.Constant.of_int 1) in
  let two = Impl.constant Impl.Field.typ (Impl.Field.Constant.of_int 2) in
  let res = Impl.Field.add input one in
  Impl.Field.Assert.equal res two

(* field as a bunch of helpers that can make this more concise: *)
let circuit1 input _ : unit (* no output *) =
  (* field defines a helper [constant]. *)
  let two = Impl.Field.constant (Impl.Field.Constant.of_int 2) in
  (* Field redefines [+] and [one] as well .*)
  let res = Impl.Field.(input + one) in
  Impl.Field.Assert.equal res two

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

(***************************************
  * Exercise 2: input1 + input2 == 2.  *
  **************************************)

let circuit2 (input : Impl.Field.t * Impl.Field.t) _ : unit =
  let res = Impl.Field.(fst input + snd input) in
  let two = Impl.Field.constant (Impl.Field.Constant.of_int 2) in
  Impl.Field.Assert.equal res two

let input_typ = Impl.Typ.(tuple2 field field)

(* check if it compiles and runs *)
let () =
  let input_val = Impl.Field.Constant.(of_int 1, of_int 1) in
  let (_ : Impl.Proof_inputs.t) =
    generate_witness ~input_typ ~input_val circuit2
  in
  ()

(* check serialization *)
let () =
  let compiled = compile ~input_typ circuit2 in
  let serialized = serialize compiled in
  Format.printf "%s@." serialized

(*********************************************************
  * Exercise 3:                                          *
  * if b { assert!(priv) } else if !b { assert!(!priv).  *
  ********************************************************)

type my_boolean_type = unit (* todo *)

let input_typ : (my_boolean_type, bool) Impl.Typ.t =
  Typ
    { var_to_fields = (fun my_boolean_type -> failwith "todo")
    ; var_of_fields = (fun (cvars, _) -> failwith "todo")
    ; value_to_fields = (fun b -> failwith "todo")
    ; value_of_fields = (fun (fields, _) -> failwith "todo")
    ; size_in_field_elements = failwith "todo"
    ; constraint_system_auxiliary = (fun () -> ())
    ; check =
        (fun my_boolean_type -> Impl.make_checked (fun _ -> failwith "todo"))
    }

(* our first gadget! *)
let is_true (var : my_boolean_type) : unit = failwith "how can I check that.."

let circuit3 (input : my_boolean_type) _ : unit = is_true input

(* check if it compiles and runs *)
let () =
  ( match generate_witness ~input_typ ~input_val:false circuit3 with
  | exception _ ->
      Format.printf "correctly failed@."
  | _ ->
      failwith "passing `false` to the circuit should have failed" ) ;
  let (_ : Impl.Proof_inputs.t) =
    generate_witness ~input_typ ~input_val:true circuit3
  in
  ()

(* check serialization *)
let () =
  let compiled = compile ~input_typ circuit3 in
  let serialized = serialize compiled in
  Format.printf "%s@." serialized
