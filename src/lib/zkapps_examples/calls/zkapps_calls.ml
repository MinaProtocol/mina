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
  Zkapps_examples.wrap_main (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let initial_state =
        List.map ~f:Field.constant (Lazy.force initial_state)
      in
      let party =
        party |> Party_under_construction.In_circuit.assert_state_unproved
        |> Party_under_construction.In_circuit.set_full_state initial_state
      in
      (party, None) )

let call_data_hash ~old_state ~new_state ~blinding_value =
  let open Random_oracle.Checked in
  Array.reduce_exn ~f:Random_oracle_input.Chunked.append
    Random_oracle_input.Chunked.
      [| field blinding_value
       ; field_elements (Array.of_list old_state)
       ; field_elements (Array.of_list new_state)
      |]
  |> pack_input
  |> update ~state:initial_state
  |> digest

type _ Snarky_backendless.Request.t +=
  | Old_state : Field.Constant.t list Snarky_backendless.Request.t
  | Call_data :
      Field.Constant.t list
      -> ( (Field.Constant.t list * Field.Constant.t)
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
         Snarky_backendless.Request.t

let update_state_handler (old_state : Field.Constant.t list)
    (compute_call :
         Field.Constant.t list
      -> (Field.Constant.t list * Field.Constant.t)
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Old_state ->
      respond (Provide old_state)
  | Call_data input ->
      respond (Provide (compute_call input))
  | _ ->
      respond Unhandled

let update_state_call public_key =
  Zkapps_examples.wrap_main (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let old_state =
        exists (Typ.list ~length:8 Field.typ) ~request:(fun () -> Old_state)
      in
      let (new_state, blinding_value), called_party, sub_calls =
        exists
          (Typ.tuple3
             Typ.(list ~length:8 Field.typ * Field.typ)
             (Zkapp_call_forest.Checked.party_typ ())
             Zkapp_call_forest.typ )
          ~request:(fun () ->
            let input =
              As_prover.read (Typ.list ~length:8 Field.typ) old_state
            in
            Call_data input )
      in
      let () =
        (* Check that previous party's call data is consistent. *)
        let call_data_hash =
          call_data_hash ~old_state ~new_state ~blinding_value
        in
        Field.Assert.equal call_data_hash called_party.party.data.call_data
      in
      let party =
        party |> Party_under_construction.In_circuit.assert_state_proved
        |> Party_under_construction.In_circuit.set_full_state old_state
        |> Party_under_construction.In_circuit.call called_party sub_calls
      in
      (party, None) )

type _ Snarky_backendless.Request.t +=
  | Call_input : Field.Constant.t list Snarky_backendless.Request.t

let call_handler (call_input : Field.Constant.t list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Call_input ->
      respond (Provide call_input)
  | _ ->
      respond Unhandled

let call public_key =
  Zkapps_examples.wrap_main (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let old_state =
        exists (Typ.list ~length:8 Field.typ) ~request:(fun () -> Call_input)
      in
      let blinding_value = exists Field.typ ~compute:Field.Constant.random in
      let modify_value = exists Field.typ ~compute:Field.Constant.random in
      let new_state =
        List.map old_state ~f:(fun x -> Field.add x modify_value)
      in
      let call_data_hash =
        call_data_hash ~old_state ~new_state ~blinding_value
      in
      let party =
        party |> Party_under_construction.In_circuit.assert_state_proved
        |> Party_under_construction.In_circuit.set_call_data call_data_hash
      in
      (party, Some (new_state, blinding_value)) )

type _ Snarky_backendless.Request.t +=
  | Recursive_call_input : Field.Constant.t list Snarky_backendless.Request.t
  | Recursive_call_data :
      Field.Constant.t list
      -> ( (Field.Constant.t list * Field.Constant.t)
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
         Snarky_backendless.Request.t

let recursive_call_handler (recursive_call_input : Field.Constant.t list)
    (compute_call :
         Field.Constant.t list
      -> (Field.Constant.t list * Field.Constant.t)
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Recursive_call_input ->
      respond (Provide recursive_call_input)
  | Recursive_call_data input ->
      respond (Provide (compute_call input))
  | _ ->
      respond Unhandled

let recursive_call public_key =
  Zkapps_examples.wrap_main (fun () ->
      let party =
        Party_under_construction.In_circuit.create
          ~public_key:(Public_key.Compressed.var_of_t public_key)
          ~token_id:Token_id.(Checked.constant default)
          ()
      in
      let old_state =
        exists (Typ.list ~length:8 Field.typ) ~request:(fun () ->
            Recursive_call_input )
      in
      let (new_state, blinding_value), called_party, sub_calls =
        exists
          (Typ.tuple3
             Typ.(list ~length:8 Field.typ * Field.typ)
             (Zkapp_call_forest.Checked.party_typ ())
             Zkapp_call_forest.typ )
          ~request:(fun () ->
            let input =
              As_prover.read (Typ.list ~length:8 Field.typ) old_state
            in
            Recursive_call_data input )
      in
      let () =
        (* Check that previous party's call data is consistent. *)
        let call_data_hash =
          call_data_hash ~old_state ~new_state ~blinding_value
        in
        Field.Assert.equal call_data_hash called_party.party.data.call_data
      in
      let blinding_value = exists Field.typ ~compute:Field.Constant.random in
      let modify_value = exists Field.typ ~compute:Field.Constant.random in
      let new_state =
        List.map old_state ~f:(fun x -> Field.add x modify_value)
      in
      let call_data_hash =
        call_data_hash ~old_state ~new_state ~blinding_value
      in
      let party =
        party |> Party_under_construction.In_circuit.assert_state_proved
        |> Party_under_construction.In_circuit.set_call_data call_data_hash
        |> Party_under_construction.In_circuit.call called_party sub_calls
      in
      (party, Some (new_state, blinding_value)) )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize snapp"; prevs = []; main = initialize public_key }

let update_state_call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update state call"
  ; prevs = []
  ; main = update_state_call public_key
  }

let call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Call"; prevs = []; main = call public_key }

let recursive_call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Recursive call"
  ; prevs = []
  ; main = recursive_call public_key
  }
