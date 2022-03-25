open Pickles_types.Hlist
open Snark_params.Tick
open Signature_lib
open Mina_base
open Zkapps_examples

(* TODO: Move this somewhere convenient. *)
let dummy_constraints () =
  let open Run in
  let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
  let g = exists Inner_curve.typ ~compute:(fun _ -> Inner_curve.one) in
  ignore
    ( Pickles.Scalar_challenge.to_field_checked'
        (module Impl)
        ~num_bits:16
        (Kimchi_backend_common.Scalar_challenge.create x)
      : Field.t * Field.t * Field.t ) ;
  ignore
    ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
      : Pickles.Step_main_inputs.Inner_curve.t ) ;
  ignore
    ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
      : Pickles.Step_main_inputs.Inner_curve.t ) ;
  ignore
    ( Pickles.Pairing_main.Scalar_challenge.endo g ~num_bits:4
        (Kimchi_backend_common.Scalar_challenge.create x)
      : Field.t * Field.t )

(* TODO: Should be able to *return* stmt instead of consuming it.
         Modify snarky to do this.
*)
let main public_key ([] : _ H1.T(Id).t)
    ({ transaction; at_party } : Snapp_statement.Checked.t) :
    _ H1.T(E01(Pickles.Inductive_rule.B)).t =
  dummy_constraints () ;
  let party =
    Party_under_construction.In_circuit.create
      ~public_key:(Public_key.Compressed.var_of_t public_key)
      ~token_id:Token_id.(Checked.constant default)
      ()
  in
  let party = Party_under_construction.In_circuit.to_party party in
  let returned_transaction = Party.Predicated.Checked.digest party in
  let returned_at_party =
    (* TODO: This should be returned from
             [Party_under_construction.In_circuit.to_party].
    *)
    Field.Var.constant Parties.Call_forest.empty
  in
  Run.Field.Assert.equal returned_transaction transaction ;
  Run.Field.Assert.equal returned_at_party at_party ;
  []

(* TODO: This shouldn't exist, the circuit should just return the requisite
         values.
*)
let main_value ([] : _ H1.T(Id).t) (_ : Snapp_statement.t) :
    _ H1.T(E01(Core_kernel.Bool)).t =
  []

let rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Empty update"
  ; prevs = []
  ; main = main public_key
  ; main_value
  }

(* TODO: This shouldn't exist, the circuit should just return the requisite
         value.
*)
let generate_party public_key =
  Party_under_construction.create ~public_key ~token_id:Token_id.default ()
  |> Party_under_construction.to_party
