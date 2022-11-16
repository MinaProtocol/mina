open Core_kernel
open Snark_params.Tick.Run
open Signature_lib
open Mina_base
open Pickles_types

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

let lazy_compiled =
  lazy
    (Zkapps_examples.compile () ~cache:Cache_dir.cache
       ~auxiliary_typ:Impl.Typ.unit
       ~branches:(module Nat.N2)
       ~max_proofs_verified:(module Nat.N0)
       ~name:"tokens"
       ~constraint_constants:
         Genesis_constants.Constraint_constants.(to_snark_keys_header compiled)
       ~choices:(fun ~self:_ ->
         [ Rules.Initialize_state.rule; Rules.Update_state.rule ] ) )

let compile () = ignore (Lazy.force lazy_compiled : _)

let tag = Lazy.map lazy_compiled ~f:(fun (tag, _, _, _) -> tag)

let vk = Lazy.map ~f:Pickles.Side_loaded.Verification_key.of_compiled tag

let p_module = Lazy.map lazy_compiled ~f:(fun (_, _, p_module, _) -> p_module)

module P = struct
  type statement = Zkapp_statement.t

  type t = (Nat.N0.n, Nat.N0.n) Pickles.Proof.t

  module type Proof_intf =
    Pickles.Proof_intf with type statement = statement and type t = t

  let verification_key =
    Lazy.bind p_module ~f:(fun (module P : Proof_intf) -> P.verification_key)

  let id = Lazy.bind p_module ~f:(fun (module P : Proof_intf) -> P.id)

  let verify statements =
    let module P : Proof_intf = (val Lazy.force p_module) in
    P.verify statements

  let verify_promise statements =
    let module P : Proof_intf = (val Lazy.force p_module) in
    P.verify_promise statements
end

let initialize_prover =
  Lazy.map lazy_compiled
    ~f:(fun (_, _, _, Pickles.Provers.[ initialize_prover; _ ]) ->
      initialize_prover )

let initialize public_key token_id =
  let initialize_prover = Lazy.force initialize_prover in
  initialize_prover
    ~handler:(Rules.Initialize_state.handler public_key token_id)

let update_state_prover =
  Lazy.map lazy_compiled
    ~f:(fun (_, _, _, Pickles.Provers.[ _; update_state_prover ]) ->
      update_state_prover )

let update_state public_key token_id new_state =
  let update_state_prover = Lazy.force update_state_prover in
  update_state_prover
    ~handler:(Rules.Update_state.handler public_key token_id new_state)
