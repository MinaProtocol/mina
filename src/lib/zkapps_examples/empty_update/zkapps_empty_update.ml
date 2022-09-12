open Signature_lib
open Mina_base
open Zkapps_examples

(* TODO: Should be able to *return* stmt instead of consuming it.
         Modify snarky to do this.
*)
let main public_key =
  Zkapps_examples.wrap_main (fun () ->
      Account_update_under_construction.In_circuit.create
        ~public_key:(Public_key.Compressed.var_of_t public_key)
        ~token_id:Token_id.(Checked.constant default)
        () )

let rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Empty update"
  ; prevs = []
  ; main = main public_key
  ; uses_lookup = false
  }

(* TODO: This shouldn't exist, the circuit should just return the requisite
         value.
*)
let generate_account_update public_key =
  Account_update_under_construction.create ~public_key
    ~token_id:Token_id.default ()
  |> Account_update_under_construction.to_account_update
