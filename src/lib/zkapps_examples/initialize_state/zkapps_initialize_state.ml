open Core_kernel
open Snark_params.Tick.Run
open Signature_lib
open Mina_base
open Zkapps_examples

let initial_state =
  lazy
    [ Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ; Field.Constant.zero
    ]

let initialize public_key =
  Zkapps_examples.party_circuit (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let initial_state =
        List.map ~f:Field.constant (Lazy.force initial_state)
      in
      party |> Party_under_construction.In_circuit.assert_state_unproved
      |> Party_under_construction.In_circuit.set_full_state initial_state )

type _ Snarky_backendless.Request.t +=
  | New_state : Field.Constant.t list Snarky_backendless.Request.t

let update_state_handler (new_state : Field.Constant.t list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | New_state ->
      respond (Provide new_state)
  | _ ->
      respond Unhandled

let update_state public_key =
  Zkapps_examples.party_circuit (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let new_state =
        exists (Typ.list ~length:8 Field.typ) ~request:(fun () -> New_state)
      in
      party |> Party_under_construction.In_circuit.assert_state_proved
      |> Party_under_construction.In_circuit.set_full_state new_state )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize snapp"; prevs = []; main = initialize public_key }

let update_state_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update state"; prevs = []; main = update_state public_key }

let generate_initialize_party public_key =
  Party_under_construction.create ~public_key ~token_id:Token_id.default ()
  |> Party_under_construction.assert_state_unproved
  |> Party_under_construction.set_full_state (Lazy.force initial_state)
  |> Party_under_construction.to_party

let generate_update_state_party public_key new_state =
  Party_under_construction.create ~public_key ~token_id:Token_id.default ()
  |> Party_under_construction.assert_state_proved
  |> Party_under_construction.set_full_state new_state
  |> Party_under_construction.to_party
