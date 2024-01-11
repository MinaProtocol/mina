open Snark_params.Tick.Run
open Signature_lib
open Mina_base

let initialize public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    ~token_id:Token_id.(Checked.constant default)
    ignore

type _ Snarky_backendless.Request.t +=
  | Updated_actions : Field.Constant.t array list Snarky_backendless.Request.t

let update_actions_handler (updated_actions : Field.Constant.t array list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Updated_actions ->
      respond (Provide updated_actions)
  | _ ->
      respond Unhandled

let num_events = 11

let event_length = 13

let update_actions public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    ~token_id:Token_id.(Checked.constant default)
    (fun account_update ->
      let actions =
        exists
          ~request:(fun () -> Updated_actions)
          (Typ.list ~length:num_events
             (Typ.array ~length:event_length Field.typ) )
      in
      account_update#add_actions actions )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize zkApp"
  ; prevs = []
  ; main = initialize public_key
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }

let update_actions_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update sequence events"
  ; prevs = []
  ; main = update_actions public_key
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }
