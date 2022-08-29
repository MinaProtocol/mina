open Snark_params.Tick.Run
open Signature_lib

let initialize public_key =
  let public_key = Public_key.Compressed.var_of_t public_key in
  Zkapps_examples.wrap_main ~public_key (fun _party -> ())

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
  let public_key = Public_key.Compressed.var_of_t public_key in
  Zkapps_examples.wrap_main ~public_key (fun party ->
      let sequence_events =
        exists
          ~request:(fun () -> Updated_sequence_events)
          (Typ.list ~length:num_events
             (Typ.array ~length:event_length Field.typ) )
      in
      party#add_sequence_events sequence_events )

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
