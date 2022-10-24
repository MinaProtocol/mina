open Snark_params.Step.Run
open Signature_lib
open Mina_base

let initialize public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    ~token_id:Token_id.(Checked.constant default)
    ignore

type _ Snarky_backendless.Request.t +=
  | Updated_events : Field.Constant.t array list Snarky_backendless.Request.t

let update_events_handler (updated_events : Field.Constant.t array list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Updated_events ->
      respond (Provide updated_events)
  | _ ->
      respond Unhandled

let num_events = 5

let event_length = 7

let update_events public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    ~token_id:Token_id.(Checked.constant default)
    (fun account_update ->
      let events =
        exists
          ~request:(fun () -> Updated_events)
          (Typ.list ~length:num_events
             (Typ.array ~length:event_length Field.typ) )
      in
      account_update#add_events events )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize zkApp"
  ; prevs = []
  ; main = initialize public_key
  ; uses_lookup = false
  }

let update_events_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update events"
  ; prevs = []
  ; main = update_events public_key
  ; uses_lookup = false
  }
