open Pickles_types.Hlist
open Signature_lib
open Mina_base
open Zkapps_examples

(* TODO: Should be able to *return* stmt instead of consuming it.
         Modify snarky to do this.
*)
let main public_key =
  Zkapps_examples.party_circuit (fun () ->
      Party_under_construction.In_circuit.create
        ~public_key:(Public_key.Compressed.var_of_t public_key)
        ~token_id:Token_id.(Checked.constant default)
        () )

(* TODO: This shouldn't exist, the circuit should just return the requisite
         values.
*)
let main_value ([] : _ H1.T(Id).t) (_ : Zkapp_statement.t) :
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
