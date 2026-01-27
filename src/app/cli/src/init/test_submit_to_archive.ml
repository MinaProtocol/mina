open Core
open Async
open Cli_lib
open Signature_lib
open Mina_base
open Mina_state

let ledger_proof_opt next_state = function
  (* Copied from the prover.ml *)
  | Some t ->
      Ledger_proof.(statement_with_sok t, underlying_proof t)
  | None ->
      ( { (Blockchain_state.ledger_proof_statement
             (Protocol_state.blockchain_state next_state) )
          with
          sok_digest = Sok_message.Digest.default
        }
      , Lazy.force Proof.transaction_dummy )

let extend_blockchain (module B : Blockchain_snark.Blockchain_snark_state.S)
    ~constraint_constants (chain : Blockchain_snark.Blockchain.t)
    (next_state : Protocol_state.Value.t) (block : Snark_transition.value)
    (t : Ledger_proof.t option) state_for_handler pending_coinbase =
  (* Copied from the prover.ml *)
  Deferred.Or_error.try_with ~here:[%here] (fun () ->
      let txn_snark_statement, txn_snark_proof =
        ledger_proof_opt next_state t
      in
      let%map (), (), proof =
        B.step
          ~handler:
            (Consensus.Data.Prover_state.handler ~constraint_constants
               state_for_handler ~pending_coinbase )
          { transition = block
          ; prev_state = Blockchain_snark.Blockchain.state chain
          ; prev_state_proof = Blockchain_snark.Blockchain.proof chain
          ; txn_snark = txn_snark_statement
          ; txn_snark_proof
          }
          next_state
      in
      Blockchain_snark.Blockchain.create ~state:next_state ~proof )

let create_genesis_proof m ~constraint_constants
    (genesis_inputs : Genesis_proof.Inputs.t) =
  (* Copied from block_producer.ml *)
  let ( blockchain
      , protocol_state
      , snark_transition
      , ledger_proof_opt
      , prover_state
      , pending_coinbase ) =
    Prover.create_genesis_block_inputs genesis_inputs
  in
  (* In block producer you'd see a call to [Prover.t] component,
     which is a wrapper around [extend_blockchain] executed in a parallel process.
     Here we just do it inline. *)
  extend_blockchain m ~constraint_constants blockchain protocol_state
    snark_transition ledger_proof_opt prover_state pending_coinbase

module type Keys_S = sig
  module T : Transaction_snark.S

  module B : Blockchain_snark.Blockchain_snark_state.S
end

(* Copied from prover.ml, Worker_state.create *)
module Keys (Params : sig
  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : Keys_S = struct
  module T = Transaction_snark.Make (struct
    let signature_kind = Mina_signature_kind.Testnet

    include Params
  end)

  module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    include Params
  end)
end

(* Just a stub trust system copied from tests *)
let trust_system =
  let s = Trust_system.null () in
  don't_wait_for
    (Pipe_lib.Strict_pipe.Reader.iter
       (Trust_system.upcall_pipe s)
       ~f:(const Deferred.unit) ) ;
  s

module Block = struct
  type t =
    { breadcrumb : Frontier_base.Breadcrumb.t
    ; staged_ledger : Staged_ledger.t
    ; proof : Proof.t
    }

  let protocol_state t = Frontier_base.Breadcrumb.protocol_state t.breadcrumb

  let consensus_state_with_hashes t =
    Frontier_base.Breadcrumb.consensus_state_with_hashes t.breadcrumb

  let state_timestamp t =
    Blockchain_state.timestamp @@ Protocol_state.blockchain_state
    @@ protocol_state t

  let state_hash t = Frontier_base.Breadcrumb.state_hash t.breadcrumb

  let compute_genesis ~logger ~precomputed_values (module Keys : Keys_S) =
    (* Generate genesis block, used in a bunch of other places
       (including block producer and tests) *)
    let genesis_block_with_hash, genesis_validation =
      Mina_block.genesis ~precomputed_values
    in
    let validated =
      Mina_block.Validated.lift (genesis_block_with_hash, genesis_validation)
    in
    let constraint_constants = precomputed_values.constraint_constants in
    (* Create a staged ledger out of genesis ledger.
       Fresh code, not copied from anywhere else. *)
    (* Load the genesis ledger, should be read-only. *)
    let genesis_ledger =
      Precomputed_values.genesis_ledger precomputed_values |> Lazy.force
    in
    (* Create a mask for the ledger to catch all of the modifications
       that we make on top of genesis ledger, so that the genesis ledger
       remains unchanged. *)
    let mask =
      Mina_ledger.Ledger.Mask.create ~depth:constraint_constants.ledger_depth ()
    in
    let ledger = Mina_ledger.Ledger.register_mask genesis_ledger mask in
    (* Create a staged ledger from the ledger. *)
    let staged_ledger =
      (* [create_exn] is only safe to use for initial genesis block. *)
      Staged_ledger.create_exn ~constraint_constants ~ledger
    in
    let accounts_created =
      Precomputed_values.accounts precomputed_values
      |> Lazy.force
      |> List.map ~f:Precomputed_values.id_of_account_record
    in
    [%log info] "Generating genesis breadcrumb" ;
    let breadcrumb =
      Frontier_base.Breadcrumb.create ~validated_transition:validated
        ~staged_ledger
        ~transition_receipt_time:(Some (Time.now ()))
        ~just_emitted_a_proof:false ~accounts_created
    in
    (* Block proof contained in genesis header is just a stub.
       Hence we need to generate the real proof here, in order to
       be able to produce some new blocks. *)
    [%log info] "Generating genesis proof" ;
    let%map proof =
      create_genesis_proof
        (module Keys.B)
        ~constraint_constants
        (Genesis_proof.to_inputs precomputed_values)
      >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
    in
    { breadcrumb; staged_ledger; proof }

  let block_with_hash t = Frontier_base.Breadcrumb.block_with_hash t.breadcrumb

  let of_breadcrumb breadcrumb =
    let staged_ledger = Frontier_base.Breadcrumb.staged_ledger breadcrumb in
    let proof =
      Frontier_base.Breadcrumb.block breadcrumb
      |> Mina_block.header |> Mina_block.Header.protocol_state_proof
    in
    { breadcrumb; staged_ledger; proof }
end

let find_winning_slots ~context:(module Context : Consensus.Intf.CONTEXT)
    ~precomputed_values ~n_blocks ~keypair (genesis : Block.t) =
  let public_key_compressed = Public_key.compress keypair.Keypair.public_key in
  let logger = Context.logger in
  [%log info] "Loaded keypair for public key: %s"
    (Public_key.Compressed.to_base58_check public_key_compressed) ;
  (* Copied from CLI entry point. Needed for generating the first epoch data *)
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.Precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location:"epoch_ledger"
      (Public_key.Compressed.Set.singleton public_key_compressed)
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Stable_db
  in
  let consensus_state =
    Mina_state.Protocol_state.consensus_state (Block.protocol_state genesis)
  in
  let time_to_ms =
    Fn.compose Block_time.Span.to_ms Block_time.to_span_since_epoch
  in
  (* Copied from block producer. We generate VRF evaluator's
     inputs for the very first epoch *)
  let epoch_data_for_vrf, ledger_snapshot =
    Consensus.Hooks.get_epoch_data_for_vrf
      ~constants:Context.consensus_constants
      (time_to_ms @@ Block.state_timestamp genesis)
      consensus_state ~local_state:consensus_local_state ~logger
  in
  let { Consensus.Data.Epoch_data_for_vrf.epoch_ledger
      ; epoch_seed
      ; epoch = _
      ; global_slot = epoch_start_hf
      ; global_slot_since_genesis = epoch_start
      ; delegatee_table
      } =
    epoch_data_for_vrf
  in
  [%log info] "Generated epoch data for vrf: global slot %s, since genesis: %s"
    (Mina_numbers.Global_slot_since_hard_fork.to_string epoch_start_hf)
    (Mina_numbers.Global_slot_since_genesis.to_string epoch_start) ;
  Deferred.repeat_until_finished (1, [], 100)
  @@ fun (current_slot, found_slots, attempts_left) ->
  if List.length found_slots >= n_blocks then
    return (`Finished (List.rev found_slots))
  else if attempts_left <= 0 then (
    [%log error] "Could not find enough winning slots after many attempts" ;
    failwith "Could not find enough winning slots" )
  else
    let global_slot =
      Mina_numbers.Global_slot_since_hard_fork.of_int current_slot
    in
    (* Copied from VRF evaluator. This evaluates VRF function for
       a single pair of block-producer and slot. Inside it actually
       tests every account that delegates to this block producer
       for the slot. *)
    match%map
      Consensus.Data.Vrf.check
        ~context:(module Context)
        ~global_slot ~seed:epoch_seed
        ~get_delegators:(Public_key.Compressed.Table.find delegatee_table)
        ~producer_private_key:keypair.private_key
        ~producer_public_key:public_key_compressed
        ~total_stake:epoch_ledger.total_currency
      |> Interruptible.force
    with
    | Error _ ->
        [%log fatal] "VRF check failed" ;
        failwith "VRF check failed"
    | Ok None ->
        (* Not a winning slot, try next one *)
        `Repeat (current_slot + 1, found_slots, attempts_left - 1)
    | Ok
        (Some
          (`Vrf_eval _vrf_eval, `Vrf_output vrf_result, `Delegator delegator) )
      ->
        (* Copied from VRF evaluator *)
        [%log info] "Found winning slot at global slot %d" current_slot ;
        let slot_won =
          { Consensus.Data.Slot_won.delegator
          ; producer = keypair
          ; global_slot
          ; global_slot_since_genesis =
              (* Converting slot since HF to slot since genesis in a way that accounts for
                 section `fork` in the runtime config. *)
              Mina_numbers.Global_slot_since_genesis.add epoch_start
                ( Mina_numbers.Global_slot_since_hard_fork.diff global_slot
                    epoch_start_hf
                |> Option.value_exn ~message:"failed to diff global slots" )
          ; vrf_result
          }
        in
        `Repeat
          ( current_slot + 1
          , (slot_won, ledger_snapshot) :: found_slots
          , attempts_left - 1 )

let build_breadcrumb ~transactions ~context ~precomputed_values ~verifier
    (module Keys : Keys_S) (slot_won, ledger_snapshot) previous =
  let module V = Mina_block.Validation in
  let (module Context : V.CONTEXT) = context in
  let open Context in
  (* Copied from block producer, needed for a call to [generate_next_state] *)
  let block_data =
    Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
      ~coinbase_receiver:`Producer
  in
  (* TODO: consider using a similar logic before VRF evaluation ? Or debug this one.
     Now it produces Error logs about wrong timing of block creation w.r.t. VRF result. *)
  (* Offset block creation time so that when breadcrumb
     is created appears just right for the consensus.
     We're creating blocks sequentially one by one without 3-minutes pauses in
     between, for that reason we need to offset block creation time. *)
  Block_time.Controller.enable_setting_offset () ;
  let scheduled_time =
    Consensus.Data.Consensus_time.(
      start_time ~constants:consensus_constants
        (of_global_slot ~constants:consensus_constants slot_won.global_slot))
  in
  Block_time.Controller.set_time_offset
    ( Block_time.Span.to_time_span
    @@ Block_time.diff
         (Block_time.now @@ Block_time.Controller.basic ~logger)
         scheduled_time ) ;
  (* Time controller created below will use the time offset set above.  *)
  let time_controller = Block_time.Controller.basic ~logger in
  let previous_protocol_state = Block.protocol_state previous in
  let winner_pk = fst slot_won.delegator in
  (* Copied from block producer, creates inputs for
     generating a new block's proof, header and body. *)
  let%bind protocol_state, internal_transition, pending_coinbase_witness =
    Block_producer.generate_next_state ~commit_id:"" ~constraint_constants
      ~scheduled_time ~block_data ~previous_protocol_state ~time_controller
      ~staged_ledger:previous.staged_ledger ~transactions
      ~get_completed_work:(const None) ~logger ~log_block_creation:false
      ~winner_pk ~block_reward_threshold:None ~zkapp_cmd_limit:None
      ~zkapp_cmd_limit_hardcap:128 ~slot_tx_end:None ~slot_chain_end:None
      ~signature_kind:Testnet
    |> Interruptible.force
    >>| Result.map_error ~f:(fun () ->
            Error.of_string "unexpected interruption" )
    >>| Or_error.ok_exn
    >>| Option.value_exn ?here:None ?error:None
          ~message:"generate_next_state failed"
  in
  [%log info]
    "Generated protocol state and internal transition with %d commands"
    ( Mina_block.Internal_transition.staged_ledger_diff internal_transition
    |> Staged_ledger_diff.commands |> List.length ) ;
  let%bind protocol_state_proof =
    extend_blockchain
      (module Keys.B)
      ~constraint_constants
      (Blockchain_snark.Blockchain.create ~proof:previous.proof
         ~state:previous_protocol_state )
      protocol_state
      (Mina_block.Internal_transition.snark_transition internal_transition)
      (Mina_block.Internal_transition.ledger_proof internal_transition)
      (Mina_block.Internal_transition.prover_state internal_transition)
      pending_coinbase_witness
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
  in
  let previous_state_hash = Block.state_hash previous in
  (* Protocol is configured with [delta = 0], and for that reason
     we specify an empty list of delta block chain proofs.

     TODO: consider failing if [delta] is not 0.
     If we attempt to run with a different [delta], we need to
     specify the correct delta block chain proofs. *)
  let delta_block_chain_proof = (previous_state_hash, []) in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof
      ~delta_block_chain_proof ()
  in
  let body =
    Mina_block.Body.create
    @@ Mina_block.Internal_transition.staged_ledger_diff internal_transition
  in
  (* Copied from block producer, wraps the header and body into a transition
     with validation. *)
  let transition =
    let open Result.Let_syntax in
    V.wrap_header
      { With_hash.hash = Protocol_state.hashes protocol_state; data = header }
    |> V.skip_delta_block_chain_validation
         `This_block_was_not_received_via_gossip
    |> V.skip_time_received_validation `This_block_was_not_received_via_gossip
    |> Fn.flip V.with_body body
    |> V.skip_protocol_versions_validation
         `This_block_has_valid_protocol_versions
    |> V.validate_genesis_protocol_state_block
         ~genesis_state_hash:
           (Protocol_state.genesis_state_hash
              ~state_hash:(Some previous_state_hash) previous_protocol_state )
    >>| V.skip_proof_validation `This_block_was_generated_internally
    >>= V.validate_frontier_dependencies ~to_header:Mina_block.header ~context
          ~root_consensus_state:(Block.consensus_state_with_hashes previous)
          ~is_block_in_frontier:(State_hash.equal previous_state_hash)
    |> Result.map_error
         ~f:(const (Error.of_string "failed to validate just created block"))
    |> Or_error.ok_exn
  in
  let transition_receipt_time = Some (Time.now ()) in
  [%log info] "Building breadcrumb" ;
  (* Create breadcrumb using parent and the new block transition that we just generated.
     Most of the logic of the function call below is for updating the staged ledger. *)
  (* We use [~get_completed_work:(Fn.const None)] because we don't run a snark worker
       in this test. Hence, nobody is creating snark work. It's fine to create a few blocks
     with this tool as when the blockchain is started from genesis, scan state has ~750
      transaction slots empty and snark work production is necessary only after that. *)
  Frontier_base.Breadcrumb.build ~logger ~precomputed_values ~verifier
    ~get_completed_work:(Fn.const None) ~trust_system
    ~parent:previous.breadcrumb ~transition ~sender:None
    ~skip_staged_ledger_verification:`All ~transition_receipt_time ()
  >>| Result.map_error ~f:(const @@ Error.of_string "failed to build breadcrumb")
  >>| Or_error.ok_exn

let mk_payment ~(valid_until : Mina_numbers.Global_slot_since_genesis.t)
    ~signer_pk ~nonce signer_keypair =
  (* Fresh code which demonstrates the simplest
     possible way to construct a payment *)
  let fresh_keypair = Keypair.create () in
  let receiver_pk = Public_key.compress fresh_keypair.Keypair.public_key in
  let common =
    { Signed_command_payload.Common.Poly.fee =
        Currency.Fee.of_nanomina_int_exn 1000000
    ; fee_payer_pk = signer_pk
    ; nonce
    ; valid_until
    ; memo = Signed_command_memo.empty
    }
  in
  let payload =
    { Signed_command_payload.Poly.common
    ; body =
        Signed_command_payload.Body.Payment
          { receiver_pk; amount = Currency.Amount.of_mina_int_exn 3 }
    }
  in
  let signature =
    Signed_command.sign_payload ~signature_kind:Testnet
      signer_keypair.Keypair.private_key payload
  in
  { Signed_command.Poly.signer = signer_keypair.public_key; signature; payload }

(** Create a transaction to create [n_accounts] many zkapp accounts and insert them into 
    the accounts table.
*)
let create_zkapp_accounts_tx
    ?(fee = Currency.Fee.of_nanomina_int_exn 20_000_000)
    ?(initial_balance = Currency.Balance.of_mina_int_exn 10)
    ~constraint_constants ~sender ~nonce_ref ~n_accounts ~account_state_tbl =
  let zkapp_keypairs =
    List.init n_accounts ~f:(fun _ ->
        let sk, zkapp_account =
          Quickcheck.random_value
          @@ Account.gen_zkapp_account_with_private_key
               ~token_id:Token_id.default ~balance:initial_balance
        in
        Account_id.Table.set account_state_tbl
          ~key:(Account.identifier zkapp_account)
          ~data:(zkapp_account, `Ordinary_participant) ;
        Keypair.of_private_key_exn sk )
  in
  let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t) =
    { sender = (sender, !nonce_ref)
    ; fee
    ; fee_payer = None
    ; amount = Currency.Balance.to_amount initial_balance
    ; zkapp_account_keypairs = zkapp_keypairs
    ; memo = Signed_command_memo.create_from_string_exn "Zkapp create accounts"
    ; new_zkapp_account = true
    ; snapp_update = Account_update.Update.dummy
    ; preconditions = None
    ; authorization_kind = Signature
    }
  in
  let%map tx =
    Transaction_snark.For_tests.deploy_snapp ~constraint_constants
      ~signature_kind:Testnet zkapp_command_spec
  in
  Ref.replace nonce_ref Unsigned.UInt32.succ ;
  tx

let generate_txs ~valid_until ~nonce_ref ~n_zkapp_txs ~n_payments ~n_blocks
    ~constraint_constants ~max_cost ~account_state_tbl ~vk ~genesis_constants
    fee_payer_keypair : User_command.Valid.t Sequence.t list =
  let signer_pk = Public_key.compress fee_payer_keypair.Keypair.public_key in
  let event_elements = 12 in
  let action_elements = 12 in
  let generate_payments () =
    Sequence.init (n_payments + n_zkapp_txs) ~f:(fun i ->
        let command =
          if i < n_payments then (
            (* Creates a simple payment that initializes a new account *)
            let res =
              User_command.Signed_command
                (mk_payment ~valid_until ~nonce:!nonce_ref ~signer_pk
                   fee_payer_keypair )
            in
            Ref.replace nonce_ref Unsigned.UInt32.succ ;
            res )
          else if max_cost then (
            let max_cost_cmd =
              Quickcheck.Generator.generate
                (Mina_generators.Zkapp_command_generators
                 .gen_max_cost_zkapp_command_from
                   ~fee_payer_pk:
                     (Public_key.compress fee_payer_keypair.public_key)
                   ~account_state_tbl ~vk ~genesis_constants () )
                ~size:1
                ~random:(Splittable_random.State.create Random.State.default)
            in
            Ref.replace nonce_ref Unsigned.UInt32.succ ;
            Zkapp_command max_cost_cmd )
          else
            (* Generates a 9-account-update zkapp transaction
               creating 8 new accounts with 0 balance each *)
            let res =
              User_command.Zkapp_command
                (Test_ledger_application.mk_tx
                   ~transfer_parties_get_actions_events:true ~event_elements
                   ~action_elements ~constraint_constants fee_payer_keypair
                   !nonce_ref )
            in
            Ref.replace nonce_ref Unsigned.UInt32.succ ;
            res
        in
        (* This is used in the context of a test, and we know that the command is valid *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it
              valid_command ) =
          User_command.to_valid_unsafe command
        in
        valid_command )
  in
  List.init n_blocks ~f:(fun _ -> generate_payments ())

let load_and_initialize_config ~genesis_dir ~logger ~config_file =
  let%bind runtime_config_json =
    Genesis_ledger_helper.load_config_json config_file >>| Or_error.ok_exn
  in
  let runtime_config =
    Runtime_config.of_yojson runtime_config_json
    |> Result.map_error ~f:Error.of_string
    |> Or_error.ok_exn
  in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Compiled.proof_level in
  Genesis_ledger_helper.init_from_config_file ~genesis_constants
    ~constraint_constants ~logger ~proof_level ~cli_proof_level:None
    ~genesis_dir runtime_config
  >>| Or_error.ok_exn

let initialize_verifier_and_components ~logger
    ~(precomputed_values : Precomputed_values.t) =
  let module Context = struct
    let logger = logger

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level
  end in
  let module Keys = Keys (Context) in
  let%bind blockchain_verification_key =
    Lazy.force Keys.B.Proof.verification_key
  in
  let%bind transaction_verification_key = Lazy.force Keys.T.verification_key in
  (* Copied from CLI entrypoint. Needed for rpc-parallel initialization. *)
  Parallel.init_master () ;
  let%bind cwd = Sys.getcwd () in
  (* Copied from CLI entrypoint. Creates a verifier parallel process.
     In future we may consider not launching a parallel verifier process
     and just use a dummy implementation, or even make the [Breadcrumb.build]
     not accept the verifier as an argument when it's asked
     not to verify certain stuff. *)
  let%map verifier =
    Verifier.create ~logger ~commit_id:"" ~blockchain_verification_key
      ~transaction_verification_key ~proof_level:precomputed_values.proof_level
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:(Some (Filename.concat cwd "verifier"))
      ~signature_kind:Testnet ()
  in
  ((module Context : Consensus.Intf.CONTEXT), (module Keys : Keys_S), verifier)

let generate_all_transactions ~(precomputed_values : Precomputed_values.t)
    ~n_blocks ~n_zkapp_txs ~n_payments ~max_cost ~fee_payer_keypair genesis =
  let genesis_slot =
    Block.protocol_state genesis
    |> Protocol_state.consensus_state
    |> Consensus.Data.Consensus_state.global_slot_since_genesis
  in
  let valid_until =
    (* Just stub out valid until with enough slots that
       payment is guaranteed to pass. *)
    (* TODO: replace [n_blocks * 10] with the value of the last
       won slot + delta. *)
    Mina_numbers.Global_slot_since_genesis.add genesis_slot
      (Mina_numbers.Global_slot_span.of_int @@ (n_blocks * 10))
  in
  let signer_account_id =
    Account_id.of_public_key fee_payer_keypair.Keypair.public_key
  in
  let genesis_ledger = Staged_ledger.ledger genesis.staged_ledger in
  let nonce_ref =
    (* Retrieve the nonce of the signer's account from genesis ledger. *)
    Mina_ledger.Ledger.location_of_account genesis_ledger signer_account_id
    |> Option.value_exn ~message:"Sender's account not found in ledger"
    |> Mina_ledger.Ledger.get genesis_ledger
    |> Option.value_exn
         ~message:"Sender's account not found in ledger by location"
    |> Account.nonce |> ref
  in
  let account_state_tbl = Account_id.Table.create () in
  let genesis_accounts = Mina_ledger.Ledger.to_list_sequential genesis_ledger in
  List.iter genesis_accounts ~f:(fun account ->
      let account_id = Account.identifier account in
      let role =
        if Account_id.equal account_id signer_account_id then `Fee_payer
        else `Ordinary_participant
      in
      Account_id.Table.set account_state_tbl ~key:account_id
        ~data:(account, role) ) ;
  let vk =
    let data =
      Pickles.Side_loaded.Verification_key.(
        dummy |> to_base58_check |> of_base58_check_exn)
    in
    let hash = Zkapp_account.digest_vk data in
    { With_hash.data; hash }
  in

  (* Always generate zkApp accounts in the first block *)
  let%map gen_zk_apps_tx =
    let%map tx =
      create_zkapp_accounts_tx ?fee:None ?initial_balance:None
        ~constraint_constants:precomputed_values.constraint_constants
        ~sender:fee_payer_keypair ~nonce_ref ~n_accounts:10 ~account_state_tbl
    in
    let
        (* This is used in the context of a test, and we know that the command is valid.
           Respect my authoritah
        *)
        (`If_this_is_used_it_should_have_a_comment_justifying_it valid_command)
        =
      User_command.to_valid_unsafe (Zkapp_command tx)
    in
    valid_command
  in

  let rest_txs =
    generate_txs ~nonce_ref ~valid_until ~n_payments ~n_zkapp_txs ~n_blocks
      ~constraint_constants:precomputed_values.constraint_constants ~max_cost
      ~account_state_tbl ~vk
      ~genesis_constants:precomputed_values.genesis_constants fee_payer_keypair
  in
  List.cons (Sequence.singleton gen_zk_apps_tx) rest_txs

let create_blocks_with_diffs ~logger
    ~(precomputed_values : Precomputed_values.t) ~verifier ~context ~keys_module
    ~winning_slots ~all_transactions ~genesis =
  let%map _, diffs_rev =
    Deferred.List.fold (List.zip_exn winning_slots all_transactions)
      ~init:(genesis, [])
      ~f:(fun (block, diffs) ((slot, ledger_snapshot), transactions) ->
        let%map breadcrumb =
          build_breadcrumb ~transactions ~context ~precomputed_values ~verifier
            keys_module (slot, ledger_snapshot) block
        in
        let diff =
          (* Copied from archive_client.ml *)
          Archive_lib.Diff.Builder.breadcrumb_added ~precomputed_values ~logger
            breadcrumb
        in
        (Block.of_breadcrumb breadcrumb, diff :: diffs) )
  in
  List.rev diffs_rev

let run ~logger ~keypair ~archive_node_port ~config_file ~n_zkapp_txs
    ~n_payments ~n_blocks ~max_cost ~output_file ~genesis_dir =
  (* Section 1: Load and initialize precomputed values from config *)
  let%bind precomputed_values =
    load_and_initialize_config ~logger ~config_file ~genesis_dir
  in

  (* Section 2: Initialize verifier and other components *)
  let%bind context, keys_module, verifier =
    initialize_verifier_and_components ~logger ~precomputed_values
  in

  (* Section 3: Generate genesis block *)
  [%log info] "Generating genesis block" ;
  let%bind genesis =
    Block.compute_genesis keys_module ~precomputed_values ~logger
  in

  (* Section 4: Compute VRF to find n_blocks+1 winning slots (including zkApp deployment block) *)
  [%log info] "Computing VRF to find %d winning slots" (n_blocks + 1) ;
  let%bind winning_slots =
    find_winning_slots ~context ~precomputed_values ~n_blocks:(n_blocks + 1)
      ~keypair genesis
  in
  [%log info] "Found %d winning slots" (List.length winning_slots) ;

  (* Section 5: Generate zkApp transactions and payments *)
  [%log info]
    "Generate %d blocks (1 zkApp deployment + %d user blocks) with %d zkApp \
     transactions and %d payments"
    (n_blocks + 1) n_blocks n_zkapp_txs n_payments ;
  let%bind all_transactions =
    generate_all_transactions ~precomputed_values ~n_blocks ~n_zkapp_txs
      ~n_payments ~max_cost ~fee_payer_keypair:keypair genesis
  in

  (* Section 6: Create blocks *)
  [%log info] "Creating %d blocks" (List.length winning_slots) ;
  let%bind diffs =
    create_blocks_with_diffs ~logger ~precomputed_values ~verifier ~context
      ~keys_module ~winning_slots ~all_transactions ~genesis
  in

  (* Section 7: Submit blocks to archive or save to file *)
  let%bind () =
    match archive_node_port with
    | Some port ->
        [%log info] "Submit blocks to archive at port %d" port ;
        Deferred.List.iter diffs ~f:(fun diff ->
            (* Copied from archive_client.ml *)
            Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t
              (Transition_frontier diff)
              { host = "127.0.0.1"; port }
            >>| Or_error.ok_exn )
    | None ->
        [%log info] "Skipping archive submission (no archive port provided)" ;
        Deferred.unit
  in

  (* Section 8: Save blocks to output file if specified *)
  let%map () =
    match output_file with
    | Some file_path ->
        [%log info] "Writing blocks to file: %s" file_path ;
        let%map () =
          Async.Writer.with_file file_path ~f:(fun writer ->
              List.iter diffs ~f:(fun diff ->
                  let archive_diff =
                    Archive_lib.Diff.Transition_frontier diff
                  in
                  let serialized =
                    Bin_prot.Writer.to_bytes Archive_lib.Diff.bin_writer_t
                      archive_diff
                  in
                  Async.Writer.write_bytes writer serialized ) ;
              Deferred.unit )
        in
        [%log info] "Successfully wrote %d blocks to %s" (List.length diffs)
          file_path
    | None ->
        [%log info] "No output file specified, blocks generated in memory only" ;
        Deferred.unit
  in

  [%log info] "Test completed"

let command =
  Command.async
    ~summary:
      "Generate blocks with zkApp transactions and payments. Optionally submit \
       to archive node or save to file for analysis."
    (let open Command.Let_syntax in
    let%map_open archive_node_port =
      flag "--archive-node-port"
        ~doc:"PORT Archive node's daemon port to submit blocks to (optional)"
        (optional int)
    and config_file =
      flag "--config-file" ~doc:"FILE Path to the runtime configuration file"
        (required string)
    and genesis_dir =
      flag "--genesis-dir" ~doc:"FILE Path to the genesis ledger directory"
        (optional string)
    and privkey_path = Flag.privkey_read_path
    and n_zkapp_txs =
      flag "--num-zkapp-txs"
        ~doc:
          "NUM Number of zkApp transactions (each creating 9 account updates \
           with 8 new accounts)"
        (required int)
    and n_payments =
      flag "--num-payments"
        ~doc:"NUM Number of payment transactions to non-existing accounts"
        (required int)
    and n_blocks =
      flag "--num-blocks" ~doc:"NUM Number of blocks to generate" (required int)
    and max_cost =
      flag "--max-cost" ~doc:" Generate maximum cost zkApp transactions" no_arg
    and output_file =
      flag "--output-file"
        ~doc:
          "FILE Write generated blocks to JSON file (useful when not \
           submitting to archive)"
        (optional string)
    in
    Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let logger = Logger.create ~id:Logger.Logger_id.mina () in
    let metadata =
      [ ("config_file", `String config_file)
      ; ("n_zkapp_txs", `Int n_zkapp_txs)
      ; ("n_payments", `Int n_payments)
      ; ("n_blocks", `Int n_blocks)
      ; ("max_cost", `Bool max_cost)
      ; ("archive_node_port", [%to_yojson: int option] archive_node_port)
      ; ("output_file", [%to_yojson: int option] archive_node_port)
      ]
    in
    [%log info] "Starting submit-to-archive test" ~metadata ;
    [%log info] "Loading keypair from %s" privkey_path ;
    let%bind keypair =
      Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina keypair" privkey_path
    in
    [%log info] "Loading configuration from %s" config_file ;
    Logger.Consumer_registry.register ~commit_id:"" ~id:Logger.Logger_id.mina
      ~processor:Internal_tracing.For_logger.processor
      ~transport:
        (Internal_tracing.For_logger.json_lines_rotate_transport
           ~directory:"internal-tracing" () )
      () ;
    let log_processor =
      Logger.Processor.pretty ~log_level:Info
        ~config:
          { Interpolator_lib.Interpolator.mode = After
          ; max_interpolation_length = 50
          ; pretty_print = true
          }
    in
    Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
      ~id:Logger.Logger_id.mina ~processor:log_processor
      ~transport:(Logger.Transport.stdout ())
      () ;
    let%bind () = Internal_tracing.toggle ~commit_id:"" ~logger `Enabled in
    let genesis_dir = Option.value ~default:"genesis" genesis_dir in

    run ~logger ~keypair ~archive_node_port ~config_file ~n_zkapp_txs
      ~n_payments ~n_blocks ~max_cost ~output_file ~genesis_dir)
