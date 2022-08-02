open Core_kernel
open Snark_params.Tick.Run
open Signature_lib
open Mina_base
open Zkapps_examples

let initialize public_key =
  Zkapps_examples.wrap_main (fun () ->
      Party_under_construction.In_circuit.create
        ~public_key:(Public_key.Compressed.var_of_t public_key)
        ~token_id:Token_id.(Checked.constant default)
        () )

type _ Snarky_backendless.Request.t +=
  | Updated_events : Field.Constant.t array list Snarky_backendless.Request.t

let update_events_handler (updated_events : Field.Constant.t array list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Updated_events ->
      respond (Provide updated_events)
  | _ ->
      respond Unhandled

let events =
  List.init 4 ~f:(fun n -> Array.init (n + 1) ~f:(fun _ -> Field.Constant.one))

(* big list of events; we'll send the pieces in 3 different Partys, then reassemble them *)
let all_events = events @ events @ events

(* Merkle hash of all the events; we'll want to get this same hash after re-assembling the events *)
let all_events_hash = Mina_base.Zkapp_account.Events.hash all_events

let update_events public_key =
  Zkapps_examples.wrap_main (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      Party_under_construction.In_circuit.set_events events party )

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

let generate_initialize_party public_key =
  Party_under_construction.create ~public_key ~token_id:Token_id.default ()
  |> Party_under_construction.to_party

let generate_update_events_party public_key events =
  Party_under_construction.create ~public_key ~token_id:Token_id.default ()
  |> Party_under_construction.set_events events
  |> Party_under_construction.to_party
