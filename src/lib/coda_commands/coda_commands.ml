open Core
open Async
open Signature_lib
open Coda_numbers
open Coda_base
open Coda_state

(** For status *)
let txn_count = ref 0

let record_payment t (txn : User_command.t) account =
  let logger =
    Logger.extend
      (Coda_lib.top_level_logger t)
      [("coda_command", `String "Recording payment")]
  in
  let previous = account.Account.Poly.receipt_chain_hash in
  let receipt_chain_database = Coda_lib.receipt_chain_database t in
  match Receipt_chain_database.add receipt_chain_database ~previous txn with
  | `Ok hash ->
      [%log debug]
        ~metadata:
          [ ("command", User_command.to_yojson txn)
          ; ("receipt_chain_hash", Receipt.Chain_hash.to_yojson hash) ]
        "Added  payment $user_command into receipt_chain database. You should \
         wait for a bit to see your account's receipt chain hash update as \
         $receipt_chain_hash" ;
      hash
  | `Duplicate hash ->
      [%log warn]
        ~metadata:[("command", User_command.to_yojson txn)]
        "Already sent transaction $user_command" ;
      hash
  | `Error_multiple_previous_receipts parent_hash ->
      [%log fatal]
        ~metadata:
          [ ( "parent_receipt_chain_hash"
            , Receipt.Chain_hash.to_yojson parent_hash )
          ; ( "previous_receipt_chain_hash"
            , Receipt.Chain_hash.to_yojson previous ) ]
        "A payment is derived from two different blockchain states \
         ($parent_receipt_chain_hash, $previous_receipt_chain_hash). \
         Receipt.Chain_hash is supposed to be collision resistant. This \
         collision should not happen." ;
      Core.exit 1

let get_account t (addr : Account_id.t) =
  let open Participating_state.Let_syntax in
  let%map ledger = Coda_lib.best_ledger t in
  let open Option.Let_syntax in
  let%bind loc = Ledger.location_of_account ledger addr in
  Ledger.get ledger loc

let get_accounts t =
  let open Participating_state.Let_syntax in
  let%map ledger = Coda_lib.best_ledger t in
  Ledger.to_list ledger

let string_of_public_key =
  Fn.compose Public_key.Compressed.to_base58_check Account.public_key

let get_public_keys t =
  let open Participating_state.Let_syntax in
  let%map account = get_accounts t in
  List.map account ~f:string_of_public_key

let get_keys_with_details t =
  let open Participating_state.Let_syntax in
  let%map accounts = get_accounts t in
  List.map accounts ~f:(fun account ->
      ( string_of_public_key account
      , account.Account.Poly.balance |> Currency.Balance.to_int
      , account.Account.Poly.nonce |> Account.Nonce.to_int ) )

let get_nonce t (addr : Account_id.t) =
  let open Participating_state.Option.Let_syntax in
  let%map account = get_account t addr in
  account.Account.Poly.nonce

let get_balance t (addr : Account_id.t) =
  let open Participating_state.Option.Let_syntax in
  let%map account = get_account t addr in
  account.Account.Poly.balance

let get_trust_status t (ip_address : Unix.Inet_addr.Blocking_sexp.t) =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.lookup trust_system ip_address

let get_trust_status_all t =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.peer_statuses trust_system

let reset_trust_status t (ip_address : Unix.Inet_addr.Blocking_sexp.t) =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.reset trust_system ip_address

let replace_block_production_keys keys pks =
  let kps =
    List.filter_map pks ~f:(fun pk ->
        let open Option.Let_syntax in
        let%map kps =
          Coda_lib.wallets keys |> Secrets.Wallets.find_unlocked ~needle:pk
        in
        (kps, pk) )
  in
  Coda_lib.replace_block_production_keypairs keys
    (Keypair.And_compressed_pk.Set.of_list kps) ;
  kps |> List.map ~f:snd

let setup_and_submit_user_command t (user_command_input : User_command_input.t)
    =
  let open Participating_state.Let_syntax in
  let fee_payer = User_command_input.fee_payer user_command_input in
  let%map account_opt = get_account t fee_payer in
  let open Deferred.Let_syntax in
  let%map result = Coda_lib.add_transactions t [user_command_input] in
  txn_count := !txn_count + 1 ;
  match result with
  | Ok ([], [failed_txn]) ->
      Error
        (Error.of_string
           (sprintf !"%s"
              ( Network_pool.Transaction_pool.Resource_pool.Diff.Diff_error
                .to_yojson (snd failed_txn)
              |> Yojson.Safe.to_string )))
  | Ok ([Signed_command txn], []) ->
      [%log' info (Coda_lib.top_level_logger t)]
        ~metadata:[("command", User_command.to_yojson (Signed_command txn))]
        "Scheduled payment $command" ;
      Ok
        ( txn
        , record_payment t (Signed_command txn) (Option.value_exn account_opt)
        )
  | Ok _ ->
      Error (Error.of_string "Invalid result from scheduling a payment")
  | Error e ->
      Error e

let setup_and_submit_user_commands t user_command_list =
  let open Participating_state.Let_syntax in
  let%map _is_active = Coda_lib.active_or_bootstrapping t in
  [%log' warn (Coda_lib.top_level_logger t)]
    "batch-send-payments does not yet report errors"
    ~metadata:
      [("coda_command", `String "scheduling a batch of user transactions")] ;
  Coda_lib.add_transactions t user_command_list

module Receipt_chain_hash = struct
  (* Receipt.Chain_hash does not have bin_io *)
  include Receipt.Chain_hash.Stable.V1

  [%%define_locally
  Receipt.Chain_hash.(cons, empty)]
end

let verify_payment t (addr : Account_id.t) (verifying_txn : User_command.t)
    (init_receipt, proof) =
  let open Participating_state.Let_syntax in
  let%map account = get_account t addr in
  let account = Option.value_exn account in
  let resulting_receipt = account.Account.Poly.receipt_chain_hash in
  let open Or_error.Let_syntax in
  let%bind (_ : Receipt.Chain_hash.t Non_empty_list.t) =
    Result.of_option
      (Receipt_chain_database.verify ~init:init_receipt proof resulting_receipt)
      ~error:(Error.createf "Merkle list proof of payment is invalid")
  in
  if List.exists proof ~f:(fun txn -> User_command.equal verifying_txn txn)
  then Ok ()
  else
    Or_error.errorf
      !"Merkle list proof does not contain payment %{sexp:User_command.t}"
      verifying_txn

let prove_receipt t ~proving_receipt ~resulting_receipt =
  let receipt_chain_database = Coda_lib.receipt_chain_database t in
  (* TODO: since we are making so many reads to `receipt_chain_database`,
     reads should be async to not get IO-blocked. See #1125 *)
  let result =
    Receipt_chain_database.prove receipt_chain_database ~proving_receipt
      ~resulting_receipt
  in
  Deferred.return result

let start_time = Time_ns.now ()

type active_state_fields =
  { num_accounts: int option
  ; blockchain_length: int option
  ; ledger_merkle_root: string option
  ; state_hash: string option
  ; consensus_time_best_tip: Consensus.Data.Consensus_time.t option }

let get_status ~flag t =
  let open Coda_lib.Config in
  let config = Coda_lib.config t in
  let precomputed_values = config.precomputed_values in
  let protocol_constants = precomputed_values.genesis_constants.protocol in
  let constraint_constants = precomputed_values.constraint_constants in
  let consensus_constants = precomputed_values.consensus_constants in
  let uptime_secs =
    Time_ns.diff (Time_ns.now ()) start_time
    |> Time_ns.Span.to_sec |> Int.of_float
  in
  let commit_id = Coda_version.commit_id in
  let conf_dir = config.conf_dir in
  let%map peers = Coda_lib.peers t in
  let peers =
    List.map peers ~f:(fun peer ->
        Network_peer.Peer.to_discovery_host_and_port peer
        |> Host_and_port.to_string )
  in
  let user_commands_sent = !txn_count in
  let snark_worker =
    Option.map
      (Coda_lib.snark_worker_key t)
      ~f:Public_key.Compressed.to_base58_check
  in
  let snark_work_fee = Currency.Fee.to_int @@ Coda_lib.snark_work_fee t in
  let block_production_keys = Coda_lib.block_production_pubkeys t in
  let consensus_mechanism = Consensus.name in
  let time_controller = config.time_controller in
  let consensus_time_now =
    Consensus.Data.Consensus_time.of_time_exn ~constants:consensus_constants
      (Block_time.now time_controller)
  in
  let consensus_configuration =
    Consensus.Configuration.t ~constraint_constants ~protocol_constants
  in
  let r = Perf_histograms.report in
  let histograms =
    match flag with
    | `Performance ->
        let rpc_timings =
          let open Daemon_rpcs.Types.Status.Rpc_timings in
          { get_staged_ledger_aux=
              { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_staged_ledger_aux"
              ; impl= r ~name:"rpc_impl_get_staged_ledger_aux" }
          ; answer_sync_ledger_query=
              { Rpc_pair.dispatch=
                  r ~name:"rpc_dispatch_answer_sync_ledger_query"
              ; impl= r ~name:"rpc_impl_answer_sync_ledger_query" }
          ; get_ancestry=
              { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_ancestry"
              ; impl= r ~name:"rpc_impl_get_ancestry" }
          ; get_transition_chain_proof=
              { Rpc_pair.dispatch=
                  r ~name:"rpc_dispatch_get_transition_chain_proof"
              ; impl= r ~name:"rpc_impl_get_transition_chain_proof" }
          ; get_transition_chain=
              { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_transition_chain"
              ; impl= r ~name:"rpc_impl_get_transition_chain" } }
        in
        Some
          { Daemon_rpcs.Types.Status.Histograms.rpc_timings
          ; external_transition_latency= r ~name:"external_transition_latency"
          ; accepted_transition_local_latency=
              r ~name:"accepted_transition_local_latency"
          ; accepted_transition_remote_latency=
              r ~name:"accepted_transition_remote_latency"
          ; snark_worker_transition_time=
              r ~name:"snark_worker_transition_time"
          ; snark_worker_merge_time= r ~name:"snark_worker_merge_time" }
    | `None ->
        None
  in
  let highest_block_length_received =
    Length.to_int @@ Consensus.Data.Consensus_state.blockchain_length
    @@ Coda_transition.External_transition.Initial_validated.consensus_state
    @@ Pipe_lib.Broadcast_pipe.Reader.peek
         (Coda_lib.most_recent_valid_transition t)
  in
  let active_status () =
    let open Participating_state.Let_syntax in
    let%bind ledger = Coda_lib.best_ledger t in
    let ledger_merkle_root =
      Ledger.merkle_root ledger |> Ledger_hash.to_string
    in
    let num_accounts = Ledger.num_accounts ledger in
    let%bind state = Coda_lib.best_protocol_state t in
    let state_hash = Protocol_state.hash state |> State_hash.to_base58_check in
    let consensus_state = state |> Protocol_state.consensus_state in
    let blockchain_length =
      Length.to_int
      @@ Consensus.Data.Consensus_state.blockchain_length consensus_state
    in
    let%map sync_status =
      Coda_incremental.Status.stabilize () ;
      match
        Coda_incremental.Status.Observer.value_exn @@ Coda_lib.sync_status t
      with
      | `Bootstrap ->
          `Bootstrapping
      | `Connecting ->
          `Active `Connecting
      | `Listening ->
          `Active `Listening
      | `Offline ->
          `Active `Offline
      | `Synced ->
          `Active `Synced
      | `Catchup ->
          `Active `Catchup
    in
    let consensus_time_best_tip =
      Consensus.Data.Consensus_state.consensus_time consensus_state
    in
    ( sync_status
    , { num_accounts= Some num_accounts
      ; blockchain_length= Some blockchain_length
      ; ledger_merkle_root= Some ledger_merkle_root
      ; state_hash= Some state_hash
      ; consensus_time_best_tip= Some consensus_time_best_tip } )
  in
  let ( sync_status
      , { num_accounts
        ; blockchain_length
        ; ledger_merkle_root
        ; state_hash
        ; consensus_time_best_tip } ) =
    match active_status () with
    | `Active result ->
        result
    | `Bootstrapping ->
        ( `Bootstrap
        , { num_accounts= None
          ; blockchain_length= None
          ; ledger_merkle_root= None
          ; state_hash= None
          ; consensus_time_best_tip= None } )
  in
  let next_block_production =
    let open Block_time in
    Option.map (Coda_lib.next_producer_timing t) ~f:(function
      | `Produce_now _ ->
          `Produce_now
      | `Produce (time, _, _) ->
          `Produce (time |> Span.of_ms |> of_span_since_epoch)
      | `Check_again time ->
          `Check_again (time |> Span.of_ms |> of_span_since_epoch) )
  in
  let addrs_and_ports =
    Node_addrs_and_ports.to_display config.gossip_net_params.addrs_and_ports
  in
  { Daemon_rpcs.Types.Status.num_accounts
  ; sync_status
  ; blockchain_length
  ; highest_block_length_received
  ; uptime_secs
  ; ledger_merkle_root
  ; state_hash
  ; chain_id= config.chain_id
  ; consensus_time_best_tip
  ; commit_id
  ; conf_dir
  ; peers
  ; user_commands_sent
  ; snark_worker
  ; snark_work_fee
  ; block_production_keys=
      Public_key.Compressed.Set.to_list block_production_keys
      |> List.map ~f:Public_key.Compressed.to_base58_check
  ; histograms
  ; next_block_production
  ; consensus_time_now
  ; consensus_mechanism
  ; consensus_configuration
  ; addrs_and_ports }

let clear_hist_status ~flag t = Perf_histograms.wipe () ; get_status ~flag t

module Subscriptions = struct
  let new_block t public_key =
    let subscription = Coda_lib.subscription t in
    Coda_lib.Subscriptions.add_block_subscriber subscription public_key

  let reorganization t =
    let subscription = Coda_lib.subscription t in
    Coda_lib.Subscriptions.add_reorganization_subscriber subscription
end

module For_tests = struct
  let get_all_commands coda public_key =
    let account_id = Account_id.create public_key Token_id.default in
    let external_transition_database =
      Coda_lib.external_transition_database coda
    in
    let commands =
      List.concat_map ~f:(fun transition ->
          transition |> With_hash.data
          |> Auxiliary_database.Filtered_external_transition.commands
          |> List.map ~f:With_hash.data )
      @@ Auxiliary_database.External_transition_database.get_all_values
           external_transition_database (Some account_id)
    in
    let participants_commands =
      User_command.filter_by_participant commands public_key
    in
    List.dedup_and_sort participants_commands ~compare:User_command.compare

  module Subscriptions = struct
    let new_user_commands coda public_key =
      Coda_lib.add_payment_subscriber coda public_key
  end
end
