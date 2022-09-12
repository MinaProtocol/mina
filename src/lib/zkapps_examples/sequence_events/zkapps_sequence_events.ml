open Snark_params.Tick.Run
open Signature_lib
open Mina_base
open Zkapps_examples

let initialize public_key =
  Zkapps_examples.wrap_main (fun () ->
      Account_update_under_construction.In_circuit.create
        ~public_key:(Public_key.Compressed.var_of_t public_key)
        ~token_id:Token_id.(Checked.constant default)
        () )

type _ Snarky_backendless.Request.t +=
  | Updated_sequence_events :
      Field.Constant.t array list Snarky_backendless.Request.t

let update_sequence_events_handler
    (updated_sequence_events : Field.Constant.t array list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Updated_sequence_events ->
      respond (Provide updated_sequence_events)
  | _ ->
      respond Unhandled

let num_events = 11

let event_length = 13

let update_sequence_events public_key =
  Zkapps_examples.wrap_main (fun () ->
      let account_update =
        Account_update_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let sequence_events =
        exists
          ~request:(fun () -> Updated_sequence_events)
          (Typ.list ~length:num_events
             (Typ.array ~length:event_length Field.typ) )
      in
      Account_update_under_construction.In_circuit.add_sequence_events
        sequence_events account_update )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize zkApp"
  ; prevs = []
  ; main = initialize public_key
  ; uses_lookup = false
  }

let update_sequence_events_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update sequence events"
  ; prevs = []
  ; main = update_sequence_events public_key
  ; uses_lookup = false
  }
