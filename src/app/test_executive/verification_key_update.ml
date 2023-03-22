open Signature_lib
open Core_kernel
open Mina_base
open Integration_test_lib
module Impl = Pickles.Impls.Step

module Make_trivial_rule (Id : sig
  val id : int

  val pk_compressed : Public_key.Compressed.t
end) =
struct
  open Snark_params.Tick.Run

  let handler (Snarky_backendless.Request.With { request; respond }) =
    match request with _ -> respond Unhandled

  let main input =
    let public_key =
      exists Public_key.Compressed.typ ~compute:(fun () -> Id.pk_compressed)
    in
    Zkapps_examples.wrap_main ~public_key
      (fun account_update ->
        let id = Field.Constant.of_int Id.id in
        let x = exists Field.typ ~compute:(fun () -> id) in
        let y = Field.constant id in
        Field.Assert.equal x y ;
        account_update#set_state 0 x )
      input

  let rule : _ Pickles.Inductive_rule.t =
    { identifier = sprintf "Trivial %d" Id.id
    ; prevs = []
    ; main
    ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
    }
end

let zkapp_kp = Keypair.create ()

let zkapp_pk = Public_key.compress zkapp_kp.public_key

let zkapp_account_id = Account_id.create zkapp_pk Token_id.default

module Trivial_rule1 = Make_trivial_rule (struct
  let id = 1

  let pk_compressed = zkapp_pk
end)

module Trivial_rule2 = Make_trivial_rule (struct
  let id = 2

  let pk_compressed = zkapp_pk
end)

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "whale1-key"
          ; balance = "9000000000"
          ; timing = Untimed
          }
        ; { account_name = "whale2-key"
          ; balance = "1000000000"
          ; timing = Untimed
          }
        ; { account_name = "snark-node-key"; balance = "100"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "whale1"; account_name = "whale1-key" }
        ; { node_name = "whale2"; account_name = "whale2-key" }
        ]
    ; num_archive_nodes = 1
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; worker_nodes = 2
          }
    ; snark_worker_fee = "0.0001"
    }

  let logger = Logger.create ()

  let run network t =
    let open Malleable_error.Let_syntax in
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              (Core.String.Map.data (Network.all_nodes network)) ) )
    in
    let whale1 =
      Core.String.Map.find_exn (Network.block_producers network) "whale1"
    in
    let%bind whale1_pk = pub_key_of_node whale1 in
    let%bind whale1_sk = priv_key_of_node whale1 in
    let constraint_constants = Network.constraint_constants network in
    let (whale1_kp : Keypair.t) =
      { public_key = whale1_pk |> Public_key.decompress_exn
      ; private_key = whale1_sk
      }
    in
    (* Build the provers for the various rules. *)
    let tag1, _, _, Pickles.Provers.[ trivial_prover1 ] =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Pickles_types.Nat.N1)
        ~max_proofs_verified:(module Pickles_types.Nat.N0)
        ~name:"trivial1"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ -> [ Trivial_rule1.rule ])
    in
    let tag2, _, _, Pickles.Provers.[ trivial_prover2 ] =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Pickles_types.Nat.N1)
        ~max_proofs_verified:(module Pickles_types.Nat.N0)
        ~name:"trivial2"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ -> [ Trivial_rule2.rule ])
    in
    let vk1 = Pickles.Side_loaded.Verification_key.of_compiled tag1 in
    let vk2 = Pickles.Side_loaded.Verification_key.of_compiled tag2 in
    let%bind.Async.Deferred account_update1, _ =
      trivial_prover1 ~handler:Trivial_rule1.handler ()
    in
    let%bind.Async.Deferred account_update2, _ =
      trivial_prover2 ~handler:Trivial_rule2.handler ()
    in

    let update_vk (vk : Side_loaded_verification_key.t) : Account_update.t =
      let body (vk : Side_loaded_verification_key.t) : Account_update.Body.t =
        { Account_update.Body.dummy with
          public_key = zkapp_pk
        ; update =
            { Account_update.Update.dummy with
              verification_key =
                Set
                  { data = vk
                  ; hash =
                      (* TODO: This function should live in
                         [Side_loaded_verification_key].
                      *)
                      Zkapp_account.digest_vk vk
                  }
            ; permissions =
                Set
                  { edit_state = Proof
                  ; send = Signature
                  ; receive = Proof
                  ; set_delegate = Proof
                  ; set_permissions = Signature
                  ; set_verification_key = Signature
                  ; set_zkapp_uri = Proof
                  ; edit_action_state = Proof
                  ; set_token_symbol = Proof
                  ; increment_nonce = Signature
                  ; set_voting_for = Proof
                  ; access = None
                  ; set_timing = Signature
                  }
            }
        ; use_full_commitment = true
        ; preconditions =
            { Account_update.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Accept
            ; valid_while = Ignore
            }
        ; authorization_kind = Signature
        }
      in

      (* TODO: This is a pain. *)
      { body = body vk; authorization = Signature Signature.dummy }
    in
    let zkapp_command_create_account =
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp create account"
      in
      let (spec : Transaction_snark.For_tests.Deploy_snapp_spec.t) =
        { sender = (whale1_kp, Account.Nonce.zero)
        ; fee = Currency.Fee.of_nanomina_int_exn 20_000_000
        ; fee_payer = None
        ; amount = Currency.Amount.of_mina_int_exn 100
        ; zkapp_account_keypairs = [ zkapp_kp ]
        ; memo
        ; new_zkapp_account = true
        ; snapp_update = Account_update.Update.dummy
        ; preconditions = None
        ; authorization_kind = Signature
        }
      in
      Transaction_snark.For_tests.deploy_snapp ~constraint_constants spec
    in
    let call_forest_to_zkapp ~call_forest ~nonce : Zkapp_command.t =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Zkapp_command.Transaction_commitment.t =
        let account_updates_hash = Zkapp_command.Call_forest.hash call_forest in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash
      in
      let fee_payer : Account_update.Fee_payer.t =
        { body =
            { Account_update.Body.Fee_payer.dummy with
              public_key = zkapp_pk
            ; nonce
            ; fee = Currency.Fee.(of_nanomina_int_exn 20_000_000)
            }
        ; authorization = Signature.dummy
        }
      in
      let memo_hash = Signed_command_memo.hash memo in
      let full_commitment =
        Zkapp_command.Transaction_commitment.create_complete
          transaction_commitment ~memo_hash
          ~fee_payer_hash:
            (Zkapp_command.Call_forest.Digest.Account_update.create
               (Account_update.of_fee_payer fee_payer) )
      in
      let sign_all ({ fee_payer; account_updates; memo } : Zkapp_command.t) :
          Zkapp_command.t =
        let fee_payer =
          match fee_payer with
          | { body = { public_key; _ }; _ }
            when Public_key.Compressed.equal public_key zkapp_pk ->
              { fee_payer with
                authorization =
                  Schnorr.Chunked.sign zkapp_kp.private_key
                    (Random_oracle.Input.Chunked.field full_commitment)
              }
          | fee_payer ->
              fee_payer
        in
        let account_updates =
          Zkapp_command.Call_forest.map account_updates ~f:(function
            | ({ body = { public_key; use_full_commitment; _ }
               ; authorization = Signature _
               } as account_update :
                Account_update.t )
              when Public_key.Compressed.equal public_key zkapp_pk ->
                let commitment =
                  if use_full_commitment then full_commitment
                  else transaction_commitment
                in
                { account_update with
                  authorization =
                    Signature
                      (Schnorr.Chunked.sign zkapp_kp.private_key
                         (Random_oracle.Input.Chunked.field commitment) )
                }
            | account_update ->
                account_update )
        in
        { fee_payer; account_updates; memo }
      in
      sign_all { fee_payer; account_updates = call_forest; memo }
    in
    let call_forest1 =
      []
      |> Zkapp_command.Call_forest.cons_tree account_update1
      |> Zkapp_command.Call_forest.cons (update_vk vk1)
    in
    let zkapp_command_update_vk1 =
      call_forest_to_zkapp ~call_forest:call_forest1
        ~nonce:Account.Nonce.(of_int 0)
    in
    let call_forest2 =
      []
      |> Zkapp_command.Call_forest.cons_tree account_update1
      |> Zkapp_command.Call_forest.cons (update_vk vk2)
    in
    let zkapp_command_update_vk2_refers_vk1 =
      call_forest_to_zkapp ~call_forest:call_forest2
        ~nonce:Account.Nonce.(of_int 1)
    in
    let call_forest_update_vk2 =
      []
      |> Zkapp_command.Call_forest.cons_tree account_update2
      |> Zkapp_command.Call_forest.cons (update_vk vk2)
    in
    let zkapp_command_update_vk2 =
      call_forest_to_zkapp ~call_forest:call_forest_update_vk2
        ~nonce:Account.Nonce.(of_int 1)
    in
    let with_timeout =
      let soft_slots = 3 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp ~has_failures zkapp_command =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures
             ~zkapp_command
      in
      [%log info] "zkApp transaction included in transition frontier"
    in

    let%bind () =
      section "Send a zkApp to create a zkApp account"
        (send_zkapp ~logger whale1 zkapp_command_create_account)
    in
    let%bind () =
      section
        "Wait for zkApp to create account to be included in transition frontier"
        (wait_for_zkapp ~has_failures:false zkapp_command_create_account)
    in
    let%bind () =
      section
        "Send zkApp to update verification key to v1 and then refers to v1 in \
         the subsequent account update"
        (send_zkapp ~logger whale1 zkapp_command_update_vk1)
    in

    let%bind () =
      section
        "Send zkApp to update to a new verification key v2 and then refers to \
         the old key v1"
        (send_invalid_zkapp ~logger whale1 zkapp_command_update_vk2_refers_vk1
           "Verification_failed" )
    in
    let%bind () =
      section
        "Send zkApp to update to a new verification key v2 and then refers to \
         that"
        (send_zkapp ~logger whale1 zkapp_command_update_vk2)
    in
    let%bind () =
      section
        "Wait for zkApp to update verification key to be included in \
         transition frontier"
        (wait_for_zkapp ~has_failures:false zkapp_command_update_vk1)
    in
    section
      "Wait for zkApp to upate to a new verification key v2 and then refers to \
       it to be included in transition frontier"
      (wait_for_zkapp ~has_failures:false zkapp_command_update_vk2)
end
