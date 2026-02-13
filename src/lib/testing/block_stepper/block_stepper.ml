open Core
open Async
open Signature_lib
open Mina_base
open Mina_state
open Mina_transaction

(* Helpers for extend_blockchain, copied from prover.ml *)
let ledger_proof_opt next_state = function
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
  (* Copied from prover.ml *)
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
  extend_blockchain m ~constraint_constants blockchain protocol_state
    snark_transition ledger_proof_opt prover_state pending_coinbase

module type Keys_S = sig
  module T : Transaction_snark.S

  module B : Blockchain_snark.Blockchain_snark_state.S
end

(* Copied from prover.ml, Worker_state.create *)
module Keys (Params : sig
  val signature_kind : Mina_signature_kind.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : Keys_S = struct
  module T = Transaction_snark.Make (struct
    include Params
  end)

  module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    include Params
  end)
end

(* Null trust system stub, copied from tests *)
let trust_system =
  let s = Trust_system.null () in
  don't_wait_for
    (Pipe_lib.Strict_pipe.Reader.iter
       (Trust_system.upcall_pipe s)
       ~f:(const Deferred.unit) ) ;
  s

let prove_single ~proof_level ~proof_cache_db ~signature_kind ~sok_digest
    (module T : Transaction_snark.S)
    (spec :
      ( Transaction_witness.t
      , Ledger_proof.Cached.t )
      Snark_work_lib.Work.Single.Spec.t ) =
  match (proof_level : Genesis_constants.Proof_level.t) with
  | Check | No_check ->
      let statement = Snark_work_lib.Work.Single.Spec.statement spec in
      Deferred.return (Ledger_proof.For_tests.Cached.mk_dummy_proof statement)
  | Full -> (
      (* Convert spec to stable types: Transaction_witness.t ->
         Stable.V2.t, Ledger_proof.Cached.t -> Ledger_proof.t *)
      let single_spec =
        Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec
      in
      match single_spec with
      | Transition (input, w) -> (
          match w.transaction with
          | Command (Zkapp_command zkapp_command) ->
              let witnesses_specs_stmts =
                Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works
                  ~m:(module T)
                  ~input ~witness:w
                  ~zkapp_command:
                    (Zkapp_command.write_all_proofs_to_disk ~signature_kind
                       ~proof_cache_db zkapp_command )
                |> Result.map_error
                     ~f:
                       Work_partitioner.Snark_worker_shared
                       .Failed_to_generate_inputs
                       .error_of_t
                |> Or_error.ok_exn
              in
              let (witness, segment_spec, statement), rest =
                Mina_stdlib.Nonempty_list.uncons witnesses_specs_stmts
              in
              let%bind p1 =
                T.of_zkapp_command_segment_exn
                  ~statement:{ statement with sok_digest }
                  ~witness ~spec:segment_spec
              in
              let%map p =
                Deferred.List.fold ~init:p1 rest
                  ~f:(fun prev (witness, segment_spec, statement) ->
                    let%bind curr =
                      T.of_zkapp_command_segment_exn
                        ~statement:{ statement with sok_digest }
                        ~witness ~spec:segment_spec
                    in
                    T.merge prev curr ~sok_digest >>| Or_error.ok_exn )
              in
              Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db p
          | _ ->
              let validated_txn =
                match w.transaction with
                | Command (Signed_command cmd) -> (
                    match Signed_command.check ~signature_kind cmd with
                    | Some cmd ->
                        (Command (Signed_command cmd) : Transaction.Valid.t)
                    | None ->
                        failwith "Command has an invalid signature" )
                | Command (Zkapp_command _) ->
                    assert false
                | Fee_transfer ft ->
                    Fee_transfer ft
                | Coinbase cb ->
                    Coinbase cb
              in
              let%map proof =
                T.of_non_zkapp_command_transaction
                  ~statement:{ input with sok_digest } ~init_stack:w.init_stack
                  { Transaction_protocol_state.Poly.transaction = validated_txn
                  ; block_data = w.protocol_state_body
                  ; global_slot = w.block_global_slot
                  }
                  (unstage
                     (Mina_ledger.Sparse_ledger.handler w.first_pass_ledger) )
              in
              Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof )
      | Merge (_, proof1, proof2) ->
          let%map proof =
            T.merge proof1 proof2 ~sok_digest >>| Or_error.ok_exn
          in
          Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof )

let compute_completed_work ~proof_level ~proof_cache_db ~signature_kind
    ~protocol_states ~prover (module T : Transaction_snark.S)
    (staged_ledger : Staged_ledger.t) =
  let get_state hash =
    State_hash.Map.find protocol_states hash
    |> Result.of_option ~error:(Error.of_string "state not found")
  in
  let work_specs =
    Staged_ledger.all_work_pairs staged_ledger ~get_state |> Or_error.ok_exn
  in
  let sok_digest = Sok_message.Digest.default in
  let%map proved_work =
    Deferred.List.map work_specs ~how:`Sequential ~f:(fun one_or_two ->
        let%map proofs =
          One_or_two.Deferred.map one_or_two ~f:(fun spec ->
              prove_single ~proof_level ~proof_cache_db ~signature_kind
                ~sok_digest
                (module T)
                spec )
        in
        let statement =
          One_or_two.map one_or_two ~f:Snark_work_lib.Work.Single.Spec.statement
        in
        ( statement
        , Transaction_snark_work.Checked.create_unsafe
            { fee = Currency.Fee.zero; proofs; prover } ) )
  in
  let table = Transaction_snark_work.Statement.Table.create () in
  List.iter proved_work ~f:(fun (stmt, work) ->
      Transaction_snark_work.Statement.Table.set table ~key:stmt ~data:work ) ;
  Transaction_snark_work.Statement.Table.find table

let create_genesis_breadcrumb ~logger ~precomputed_values () =
  let signature_kind = precomputed_values.Precomputed_values.signature_kind in
  let constraint_constants = precomputed_values.constraint_constants in
  let module Params = struct
    let signature_kind = signature_kind

    let constraint_constants = constraint_constants

    let proof_level = precomputed_values.proof_level
  end in
  let module Keys = Keys (Params) in
  [%log info] "Generating genesis proof" ;
  let%map real_proof =
    create_genesis_proof
      (module Keys.B)
      ~constraint_constants
      (Genesis_proof.to_inputs precomputed_values)
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
  in
  let genesis_state =
    Precomputed_values.genesis_state_with_hashes precomputed_values
  in
  let protocol_state = With_hash.data genesis_state in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof:real_proof
      ~delta_block_chain_proof:
        (Protocol_state.previous_state_hash protocol_state, [])
      ()
  in
  let body = Mina_block.Body.create Staged_ledger_diff.empty_diff in
  let block = Mina_block.create ~header ~body in
  let block_with_hash = With_hash.map genesis_state ~f:(Fn.const block) in
  let validation =
    ( (`Time_received, Mina_stdlib.Truth.True ())
    , (`Genesis_state, Mina_stdlib.Truth.True ())
    , (`Proof, Mina_stdlib.Truth.True ())
    , ( `Delta_block_chain
      , Mina_stdlib.Truth.True
          ( Mina_stdlib.Nonempty_list.singleton
          @@ Protocol_state.previous_state_hash protocol_state ) )
    , (`Frontier_dependencies, Mina_stdlib.Truth.True ())
    , (`Staged_ledger_diff, Mina_stdlib.Truth.True ())
    , (`Protocol_versions, Mina_stdlib.Truth.True ()) )
  in
  let validated = Mina_block.Validated.lift (block_with_hash, validation) in
  let genesis_ledger =
    Precomputed_values.genesis_ledger precomputed_values |> Lazy.force
  in
  let mask =
    Mina_ledger.Ledger.Mask.create ~depth:constraint_constants.ledger_depth ()
  in
  let ledger = Mina_ledger.Ledger.register_mask genesis_ledger mask in
  let staged_ledger = Staged_ledger.create_exn ~constraint_constants ~ledger in
  let accounts_created =
    Precomputed_values.accounts precomputed_values
    |> Lazy.force
    |> List.map ~f:Precomputed_values.id_of_account_record
  in
  [%log info] "Creating genesis breadcrumb" ;
  Frontier_base.Breadcrumb.create ~validated_transition:validated ~staged_ledger
    ~transition_receipt_time:(Some (Time.now ()))
    ~just_emitted_a_proof:false ~accounts_created

let find_next_winning_slot ~context:(module Context : Consensus.Intf.CONTEXT)
    ~precomputed_values ~keypair ~start_slot ~epoch_ledger_location
    (breadcrumb : Frontier_base.Breadcrumb.t) =
  let public_key_compressed = Public_key.compress keypair.Keypair.public_key in
  let logger = Context.logger in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.Precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location
      (Public_key.Compressed.Set.singleton public_key_compressed)
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Stable_db
  in
  let breadcrumb_protocol_state =
    Frontier_base.Breadcrumb.protocol_state breadcrumb
  in
  let consensus_state =
    Mina_state.Protocol_state.consensus_state breadcrumb_protocol_state
  in
  let time_to_ms =
    Fn.compose Block_time.Span.to_ms Block_time.to_span_since_epoch
  in
  let breadcrumb_timestamp =
    Blockchain_state.timestamp @@ Protocol_state.blockchain_state
    @@ breadcrumb_protocol_state
  in
  let epoch_data_for_vrf, ledger_snapshot =
    Consensus.Hooks.get_epoch_data_for_vrf
      ~constants:Context.consensus_constants
      (time_to_ms @@ breadcrumb_timestamp)
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
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let start_epoch = start_slot / slots_per_epoch in
  Deferred.repeat_until_finished (start_slot, slots_per_epoch)
  @@ fun (current_slot, attempts_left) ->
  let current_epoch = current_slot / slots_per_epoch in
  if current_epoch > start_epoch then (
    [%log error] "Reached epoch boundary at slot %d without finding a winner"
      current_slot ;
    failwith "Could not find a winning slot in this epoch" )
  else if attempts_left <= 0 then (
    [%log error] "Could not find a winning slot after many attempts" ;
    failwith "Could not find a winning slot" )
  else
    let global_slot =
      Mina_numbers.Global_slot_since_hard_fork.of_int current_slot
    in
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
        `Repeat (current_slot + 1, attempts_left - 1)
    | Ok
        (Some
          (`Vrf_eval _vrf_eval, `Vrf_output vrf_result, `Delegator delegator) )
      ->
        [%log info] "Found winning slot at global slot %d" current_slot ;
        let slot_won =
          { Consensus.Data.Slot_won.delegator
          ; producer = keypair
          ; global_slot
          ; global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.add epoch_start
                ( Mina_numbers.Global_slot_since_hard_fork.diff global_slot
                    epoch_start_hf
                |> Option.value_exn ~message:"failed to diff global slots" )
          ; vrf_result
          }
        in
        `Finished ((slot_won, ledger_snapshot), current_slot + 1)

let build_breadcrumb ~transactions ~context ~precomputed_values ~verifier
    ~signature_kind ~proof_cache_db ~protocol_states (module Keys : Keys_S)
    (slot_won, ledger_snapshot) (previous : Frontier_base.Breadcrumb.t) =
  let module V = Mina_block.Validation in
  let (module Context : V.CONTEXT) = context in
  let open Context in
  let block_data =
    Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
      ~coinbase_receiver:`Producer
  in
  Block_time.Controller.enable_setting_offset () ;
  Block_time.Controller.set_time_offset Time.Span.zero ;
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
  let time_controller = Block_time.Controller.basic ~logger in
  let previous_protocol_state =
    Frontier_base.Breadcrumb.protocol_state previous
  in
  let previous_proof =
    Frontier_base.Breadcrumb.block previous
    |> Mina_block.header |> Mina_block.Header.protocol_state_proof
  in
  let winner_pk = fst slot_won.delegator in
  let previous_staged_ledger =
    Frontier_base.Breadcrumb.staged_ledger previous
  in
  let prover = Public_key.compress slot_won.producer.public_key in
  let%bind get_completed_work =
    compute_completed_work
      ~proof_level:precomputed_values.Precomputed_values.proof_level
      ~proof_cache_db ~signature_kind ~protocol_states ~prover
      (module Keys.T)
      previous_staged_ledger
  in
  let%bind protocol_state, internal_transition, pending_coinbase_witness =
    Block_producer.generate_next_state ~commit_id:"" ~constraint_constants
      ~scheduled_time ~block_data ~previous_protocol_state ~time_controller
      ~staged_ledger:previous_staged_ledger ~transactions ~get_completed_work
      ~logger ~log_block_creation:false ~winner_pk ~block_reward_threshold:None
      ~zkapp_cmd_limit:None ~zkapp_cmd_limit_hardcap:128 ~slot_tx_end:None
      ~slot_chain_end:None ~signature_kind
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
      (Blockchain_snark.Blockchain.create ~proof:previous_proof
         ~state:previous_protocol_state )
      protocol_state
      (Mina_block.Internal_transition.snark_transition internal_transition)
      (Mina_block.Internal_transition.ledger_proof internal_transition)
      (Mina_block.Internal_transition.prover_state internal_transition)
      pending_coinbase_witness
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
  in
  let previous_state_hash = Frontier_base.Breadcrumb.state_hash previous in
  let delta_block_chain_proof = (previous_state_hash, []) in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof
      ~delta_block_chain_proof ()
  in
  let body =
    Mina_block.Body.create
    @@ Mina_block.Internal_transition.staged_ledger_diff internal_transition
  in
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
          ~root_consensus_state:
            (Frontier_base.Breadcrumb.consensus_state_with_hashes previous)
          ~is_block_in_frontier:(State_hash.equal previous_state_hash)
    |> Result.map_error
         ~f:(const (Error.of_string "failed to validate just created block"))
    |> Or_error.ok_exn
  in
  let transition_receipt_time = Some (Time.now ()) in
  [%log info] "Building breadcrumb" ;
  Frontier_base.Breadcrumb.build ~logger ~precomputed_values ~verifier
    ~get_completed_work ~trust_system ~parent:previous ~transition ~sender:None
    ~skip_staged_ledger_verification:`All ~transition_receipt_time ()
  >>| Result.map_error ~f:(const @@ Error.of_string "failed to build breadcrumb")
  >>| Or_error.ok_exn

let initialize_verifier_and_components ~logger
    ~(precomputed_values : Precomputed_values.t) ~state_dir =
  let signature_kind = precomputed_values.signature_kind in
  let module Context = struct
    let logger = logger

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level
  end in
  let module Keys = Keys (struct
    let signature_kind = signature_kind

    include Context
  end) in
  let%bind blockchain_verification_key =
    Lazy.force Keys.B.Proof.verification_key
  in
  let%bind transaction_verification_key = Lazy.force Keys.T.verification_key in
  let verifier_dir = Filename.concat state_dir "verifier" in
  let%map verifier =
    Verifier.create ~logger ~commit_id:"" ~blockchain_verification_key
      ~transaction_verification_key ~proof_level:precomputed_values.proof_level
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:(Some verifier_dir) ~signature_kind ()
  in
  ((module Context : Consensus.Intf.CONTEXT), (module Keys : Keys_S), verifier)

type t =
  { precomputed_values : Precomputed_values.t
  ; context : (module Consensus.Intf.CONTEXT)
  ; keys_module : (module Keys_S)
  ; verifier : Verifier.t
  ; current : Frontier_base.Breadcrumb.t
  ; logger : Logger.t
  ; keypair : Keypair.t
  ; next_search_slot : int
  ; proof_cache_db : Proof_cache_tag.cache_db
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; epoch_ledger_location : string
  }

type start_state =
  { breadcrumb : Frontier_base.Breadcrumb.t
  ; protocol_states : Protocol_state.value State_hash.Map.t
  }

let start_state_of_genesis breadcrumb =
  let hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  { breadcrumb; protocol_states = State_hash.Map.singleton hash protocol_state }

let start_state_of_breadcrumb breadcrumb ~protocol_states =
  { breadcrumb; protocol_states }

let current_block t = t.current

let precomputed_values t = t.precomputed_values

let verifier t = t.verifier

let create ~precomputed_values ~keypair ~start ~logger ~state_dir () =
  let start_block = start.breadcrumb in
  let epoch_ledger_location = Filename.concat state_dir "epoch_ledger" in
  let%map context, keys_module, verifier =
    initialize_verifier_and_components ~logger ~precomputed_values ~state_dir
  in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state start_block
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.to_int |> ( + ) 1
  in
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  { precomputed_values
  ; context
  ; keys_module
  ; verifier
  ; current = start_block
  ; logger
  ; keypair
  ; next_search_slot
  ; proof_cache_db
  ; protocol_states = start.protocol_states
  ; epoch_ledger_location
  }

let step t ~transactions =
  let logger = t.logger in
  [%log info] "Searching for next winning slot from slot %d" t.next_search_slot ;
  let%bind (slot_won, ledger_snapshot), next_search_slot =
    find_next_winning_slot ~context:t.context
      ~precomputed_values:t.precomputed_values ~keypair:t.keypair
      ~start_slot:t.next_search_slot
      ~epoch_ledger_location:t.epoch_ledger_location t.current
  in
  let signature_kind = t.precomputed_values.signature_kind in
  let%map breadcrumb =
    build_breadcrumb ~transactions ~context:t.context
      ~precomputed_values:t.precomputed_values ~verifier:t.verifier
      ~signature_kind ~proof_cache_db:t.proof_cache_db
      ~protocol_states:t.protocol_states t.keys_module
      (slot_won, ledger_snapshot)
      t.current
  in
  let state_hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  let protocol_states =
    State_hash.Map.set t.protocol_states ~key:state_hash ~data:protocol_state
  in
  ( breadcrumb
  , { t with current = breadcrumb; next_search_slot; protocol_states } )
