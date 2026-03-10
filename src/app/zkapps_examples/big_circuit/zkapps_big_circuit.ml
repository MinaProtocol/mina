open Signature_lib
open Snark_params.Tick.Run
open Mina_base

(** Constructs a circuit with around [num_constraints] constraints. 
    Note that since the frontend of snarky doesn't know the number of constraints it creates, 
    we can't create a circuit the exact number of constraints we want. We can only approximate.
  *)
let big_circuit num_constraints =
  for i = 0 to num_constraints * 2 do
    let a = constant Field.typ (Field.Constant.of_int i) in
    let b = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i) in
    Field.Assert.equal a b
  done

(* Make sure that the helper works. *)
let () =
  let input_typ = Typ.unit in
  let return_typ = Typ.unit in
  let expected_constraints = 1 lsl 11 in
  let circuit _ _ = big_circuit expected_constraints in
  let cs = constraint_system ~input_typ ~return_typ circuit in
  let num_constraints =
    Kimchi_backend.Pasta.Vesta_based_plonk.R1CS_constraint_system
    .num_constraints cs
  in
  let _witness = generate_witness ~input_typ ~return_typ circuit () in
  if num_constraints < expected_constraints then (
    Format.eprintf "constraints: %d, wanted: %d@." num_constraints
      expected_constraints ;
    failwith "big_circuit doesn't work as expected anymore" )

let main ~num_constraints public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    ~token_id:Token_id.(Checked.constant default)
    (fun _account_update -> big_circuit num_constraints)

let rule ~num_constraints public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Empty update with a large circuit"
  ; prevs = []
  ; main = main ~num_constraints public_key
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }
