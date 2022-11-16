open Core_kernel
open Snark_params.Tick.Run
open Signature_lib
open Mina_base

(** Circuit requests, to get values and run code outside of the snark. *)
type _ Snarky_backendless.Request.t +=
  | Public_key : Public_key.Compressed.t Snarky_backendless.Request.t
  | Token_id : Token_id.t Snarky_backendless.Request.t
  | New_state : Field.Constant.t list Snarky_backendless.Request.t

module Rules = struct
  (** Rule to initialize the zkApp.

      Asserts that the state was not last updated by a proof (ie. the zkApp is
      freshly deployed, or that the state was modified -- tampered with --
      without using a proof).
      The app state is set to the initial state.
  *)
  module Initialize_state = struct
    let initial_state = lazy (List.init 8 ~f:(fun _ -> Field.Constant.zero))

    let handler (public_key : Public_key.Compressed.t) (token_id : Token_id.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Public_key ->
          respond (Provide public_key)
      | Token_id ->
          respond (Provide token_id)
      | _ ->
          respond Unhandled

    let main input =
      let public_key =
        exists Public_key.Compressed.typ ~request:(fun () -> Public_key)
      in
      let token_id = exists Token_id.typ ~request:(fun () -> Token_id) in
      Zkapps_examples.wrap_main ~public_key ~token_id
        (fun account_update ->
          let initial_state =
            List.map ~f:Field.constant (Lazy.force initial_state)
          in
          account_update#assert_state_unproved ;
          account_update#set_full_state initial_state )
        input

    let rule : _ Pickles.Inductive_rule.t =
      { identifier = "Initialize zkapp"; prevs = []; main; uses_lookup = false }
  end

  (** Rule to update the zkApp state.

      Asserts that the state was last updated by a proof (ie. that the zkApp
      has been correctly initialized, and all subsequent updates have been via
      proof executions).

      This calls into another zkApp method whose shape matches [Call_data], and
      uses the output value as the new state.
  *)
  module Update_state = struct
    let handler (public_key : Public_key.Compressed.t) (token_id : Token_id.t)
        (new_state : Field.Constant.t list)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Public_key ->
          respond (Provide public_key)
      | Token_id ->
          respond (Provide token_id)
      | New_state ->
          respond (Provide new_state)
      | _ ->
          respond Unhandled

    let main input =
      let public_key =
        exists Public_key.Compressed.typ ~request:(fun () -> Public_key)
      in
      let token_id = exists Token_id.typ ~request:(fun () -> Token_id) in
      Zkapps_examples.wrap_main ~public_key ~token_id
        (fun account_update ->
          let new_state =
            exists (Typ.list ~length:8 Field.typ) ~request:(fun () -> New_state)
          in
          account_update#assert_state_proved ;
          account_update#set_full_state new_state )
        input

    let rule : _ Pickles.Inductive_rule.t =
      { identifier = "Update state"; prevs = []; main; uses_lookup = false }
  end
end
