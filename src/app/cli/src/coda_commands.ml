open Core
open Async
open Pipe_lib
open Signature_lib
open Coda_numbers
open Coda_base
open Coda_state
open Coda_transition
open O1trace

module type Intf = sig
  module Program : Coda_inputs.Main_intf

  module Config_in : Coda_inputs.Config_intf

  val send_payment :
       Program.t
    -> User_command.t
    -> Receipt.Chain_hash.t Base.Or_error.t Participating_state.T.t Deferred.t

  module Subscriptions : sig
    val new_block :
         Program.t
      -> Public_key.Compressed.t
      -> External_transition.t Pipe.Reader.t

    val new_payment :
      Program.t -> Public_key.Compressed.t -> User_command.t Pipe.Reader.t
  end

  val get_all_payments :
    Program.t -> Public_key.Compressed.t -> User_command.t list

  (* TODO: Remove once we have no more functors for external_transition *)
  val payments : External_transition.t -> User_command.t list

  (* TODO: Remove once we have no more functors for external_transition *)
  val proposer : External_transition.t -> Public_key.Compressed.t
end

module Make
    (Config_in : Coda_inputs.Config_intf)
    (Program : Coda_inputs.Main_intf) =
struct
  module Program = Program
  module Config_in = Config_in
  open Program
  open Inputs

  (** For status *)
  let txn_count = ref 0

  let record_payment t (txn : User_command.t) account =
    let logger =
      Logger.extend
        (Program.top_level_logger t)
        [("coda_command", `String "Recording payment")]
    in
    let previous = account.Account.Poly.receipt_chain_hash in
    let receipt_chain_database = receipt_chain_database t in
    match Receipt_chain_database.add receipt_chain_database ~previous txn with
    | `Ok hash ->
        Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("user_command", User_command.to_yojson txn)
            ; ("receipt_chain_hash", Receipt.Chain_hash.to_yojson hash) ]
          "Added  payment $user_command into receipt_chain database. You \
           should wait for a bit to see your account's receipt chain hash \
           update as $receipt_chain_hash" ;
        hash
    | `Duplicate hash ->
        Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("user_command", User_command.to_yojson txn)]
          "Already sent transaction $user_command" ;
        hash
    | `Error_multiple_previous_receipts parent_hash ->
        Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
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

  let is_valid_payment t (txn : User_command.t) account_opt =
    let remainder =
      let open Option.Let_syntax in
      let%bind account = account_opt
      and cost =
        let fee = txn.payload.common.fee in
        match txn.payload.body with
        | Stake_delegation (Set_delegate _) ->
            Some (Currency.Amount.of_fee fee)
        | Payment {amount; _} ->
            Currency.Amount.add_fee amount fee
      in
      Currency.Balance.sub_amount account.Account.Poly.balance cost
    in
    Option.is_some remainder

  let schedule_payment t (txn : User_command.t) account_opt =
    if not (is_valid_payment t txn account_opt) then
      Or_error.error_string "Invalid payment: account balance is too low"
    else
      let txn_pool = transaction_pool t in
      don't_wait_for (Transaction_pool.add txn_pool txn) ;
      let logger =
        Logger.extend
          (Program.top_level_logger t)
          [("coda_command", `String "scheduling a payment")]
      in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("user_command", User_command.to_yojson txn)]
        "Added payment $user_command to pool successfully" ;
      txn_count := !txn_count + 1 ;
      Or_error.return ()

  let get_account t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.location_of_key ledger addr |> Option.bind ~f:(Ledger.get ledger)

  let get_accounts t =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.to_list ledger

  let string_of_public_key =
    Fn.compose Public_key.Compressed.to_base64 Account.public_key

  let get_public_keys t =
    let open Participating_state.Let_syntax in
    let%map account = get_accounts t in
    List.map account ~f:string_of_public_key

  let get_keys_with_balances t =
    let open Participating_state.Let_syntax in
    let%map accounts = get_accounts t in
    List.map accounts ~f:(fun account ->
        ( string_of_public_key account
        , account.Account.Poly.balance |> Currency.Balance.to_int ) )

  let get_nonce t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    let open Option.Let_syntax in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.Poly.nonce

  let send_payment t (txn : User_command.t) =
    Deferred.return
    @@
    let public_key = Public_key.compress txn.sender in
    let open Participating_state.Let_syntax in
    let%map account_opt = get_account t public_key in
    let open Or_error.Let_syntax in
    let%map () = schedule_payment t txn account_opt in
    record_payment t txn (Option.value_exn account_opt)

  let get_balance t (addr : Public_key.Compressed.t) =
    let open Participating_state.Option.Let_syntax in
    let%map account = get_account t addr in
    account.Account.Poly.balance

  module Receipt_chain_hash = struct
    (* Receipt.Chain_hash does not have bin_io *)
    include Receipt.Chain_hash.Stable.V1

    [%%define_locally
    Receipt.Chain_hash.(cons, empty)]
  end

  module Payment_verifier =
    Receipt_chain_database_lib.Verifier.Make
      (User_command)
      (Receipt_chain_hash)

  let verify_payment t (addr : Public_key.Compressed.Stable.Latest.t)
      (verifying_txn : User_command.t) proof =
    let open Participating_state.Let_syntax in
    let%map account = get_account t addr in
    let account = Option.value_exn account in
    let resulting_receipt = account.Account.Poly.receipt_chain_hash in
    let open Or_error.Let_syntax in
    let%bind () = Payment_verifier.verify ~resulting_receipt proof in
    if
      List.exists (Payment_proof.payments proof) ~f:(fun txn ->
          User_command.equal verifying_txn txn )
    then Ok ()
    else
      Or_error.errorf
        !"Merkle list proof does not contain payment %{sexp:User_command.t}"
        verifying_txn

  (* TODO: Properly record receipt_chain_hash for multiple transactions. See #1143 *)
  let schedule_payments t txns =
    List.map txns ~f:(fun (txn : User_command.t) ->
        let public_key = Public_key.compress txn.sender in
        let open Participating_state.Let_syntax in
        let%map account_opt = get_account t public_key in
        match schedule_payment t txn account_opt with
        | Ok () ->
            ()
        | Error err ->
            let logger =
              Logger.extend
                (Program.top_level_logger t)
                [("coda_command", `String "scheduling a payment")]
            in
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:[("error", `String (Error.to_string_hum err))]
              "Failure in schedule_payments: $error. This is not yet reported \
               to the client, see #1143" )
    |> Participating_state.sequence
    |> Participating_state.map ~f:ignore

  let prove_receipt t ~proving_receipt ~resulting_receipt :
      Payment_proof.t Deferred.Or_error.t =
    let receipt_chain_database = receipt_chain_database t in
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
    ; block_count: int option
    ; ledger_merkle_root: string option
    ; staged_ledger_hash: string option
    ; state_hash: string option
    ; consensus_time_best_tip: string option }

  let get_status ~flag t =
    let uptime_secs =
      Time_ns.diff (Time_ns.now ()) start_time
      |> Time_ns.Span.to_sec |> Int.of_float
    in
    let commit_id = Config_in.commit_id in
    let conf_dir = Config_in.conf_dir in
    let peers =
      List.map (peers t) ~f:(fun peer ->
          Network_peer.Peer.to_discovery_host_and_port peer
          |> Host_and_port.to_string )
    in
    let user_commands_sent = !txn_count in
    let run_snark_worker = Option.is_some (snark_worker_key t) in
    let propose_pubkey =
      Option.map ~f:(fun kp -> kp.public_key) (propose_keypair t)
    in
    let consensus_mechanism = Consensus.name in
    let consensus_time_now = Consensus.time_hum (Core_kernel.Time.now ()) in
    let consensus_configuration = Consensus.Configuration.t in
    let r = Perf_histograms.report in
    let histograms =
      match flag with
      | `Performance ->
          let rpc_timings =
            let open Daemon_rpcs.Types.Status.Rpc_timings in
            { get_staged_ledger_aux=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_get_staged_ledger_aux"
                ; impl= r ~name:"rpc_impl_get_staged_ledger_aux" }
            ; answer_sync_ledger_query=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_answer_sync_ledger_query"
                ; impl= r ~name:"rpc_impl_answer_sync_ledger_query" }
            ; get_ancestry=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_ancestry"
                ; impl= r ~name:"rpc_impl_get_ancestry" }
            ; transition_catchup=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_transition_catchup"
                ; impl= r ~name:"rpc_impl_transition_catchup" } }
          in
          Some
            { Daemon_rpcs.Types.Status.Histograms.rpc_timings
            ; external_transition_latency=
                r ~name:"external_transition_latency"
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
    let active_status () =
      let open Participating_state.Let_syntax in
      let%bind ledger = best_ledger t in
      let ledger_merkle_root =
        Ledger.merkle_root ledger |> [%sexp_of: Ledger_hash.t]
        |> Sexp.to_string
      in
      let num_accounts = Ledger.num_accounts ledger in
      let%bind state = best_protocol_state t in
      let state_hash =
        Protocol_state.hash state |> [%sexp_of: State_hash.t] |> Sexp.to_string
      in
      let consensus_state = state |> Protocol_state.consensus_state in
      let block_count =
        Length.to_int @@ Consensus.Data.Consensus_state.length consensus_state
      in
      let%bind sync_status =
        Coda_incremental.Status.stabilize () ;
        match Coda_incremental.Status.Observer.value_exn @@ sync_status t with
        | `Bootstrap ->
            `Bootstrapping
        | `Offline ->
            `Active `Offline
        | `Synced ->
            `Active `Synced
      in
      let%map staged_ledger = best_staged_ledger t in
      let staged_ledger_hash =
        staged_ledger |> Staged_ledger.hash |> Staged_ledger_hash.sexp_of_t
        |> Sexp.to_string
      in
      let consensus_time_best_tip =
        Consensus.Data.Consensus_state.time_hum consensus_state
      in
      ( sync_status
      , { num_accounts= Some num_accounts
        ; block_count= Some block_count
        ; ledger_merkle_root= Some ledger_merkle_root
        ; staged_ledger_hash= Some staged_ledger_hash
        ; state_hash= Some state_hash
        ; consensus_time_best_tip= Some consensus_time_best_tip } )
    in
    let ( sync_status
        , { num_accounts
          ; block_count
          ; ledger_merkle_root
          ; staged_ledger_hash
          ; state_hash
          ; consensus_time_best_tip } ) =
      match active_status () with
      | `Active result ->
          result
      | `Bootstrapping ->
          ( `Bootstrap
          , { num_accounts= None
            ; block_count= None
            ; ledger_merkle_root= None
            ; staged_ledger_hash= None
            ; state_hash= None
            ; consensus_time_best_tip= None } )
    in
    { Daemon_rpcs.Types.Status.num_accounts
    ; sync_status
    ; block_count
    ; uptime_secs
    ; ledger_merkle_root
    ; staged_ledger_hash
    ; state_hash
    ; consensus_time_best_tip
    ; commit_id
    ; conf_dir
    ; peers
    ; user_commands_sent
    ; run_snark_worker
    ; propose_pubkey
    ; histograms
    ; consensus_time_now
    ; consensus_mechanism
    ; consensus_configuration }

  let clear_hist_status ~flag t = Perf_histograms.wipe () ; get_status ~flag t

  let get_all_payments coda public_key =
    let transaction_database = Program.transaction_database coda in
    let transactions =
      Transaction_database.get_transactions transaction_database public_key
    in
    List.filter_map transactions ~f:(function
      | Coda_base.Transaction.User_command checked_user_command ->
          let user_command = User_command.forget_check checked_user_command in
          Option.some user_command
      | _ ->
          None )

  let user_commands =
    Fn.compose Staged_ledger_diff.user_commands
      External_transition.staged_ledger_diff

  let payments external_transition =
    List.filter
      (user_commands external_transition)
      ~f:(Fn.compose User_command_payload.is_payment User_command.payload)

  let proposer =
    Fn.compose Staged_ledger_diff.creator
      External_transition.staged_ledger_diff

  module Subscriptions = struct
    (* Creates a global pipe to feed a subscription that will be available throughout the entire duration that a daemon is runnning  *)
    let global_pipe coda ~to_pipe =
      let global_reader, global_writer = Pipe.create () in
      let init, _ = Pipe.create () in
      Broadcast_pipe.Reader.fold (Program.transition_frontier coda) ~init
        ~f:(fun acc_pipe -> function
        | None ->
            Deferred.return acc_pipe
        | Some transition_frontier ->
            Pipe.close_read acc_pipe ;
            let new_block_incr =
              Transition_frontier.new_transition transition_frontier
            in
            let frontier_pipe = to_pipe new_block_incr in
            Pipe.transfer frontier_pipe global_writer ~f:Fn.id
            |> don't_wait_for ;
            Deferred.return frontier_pipe )
      |> Deferred.ignore |> don't_wait_for ;
      global_reader

    let new_block coda public_key =
      global_pipe coda ~to_pipe:(fun new_block_incr ->
          let new_block_observer =
            Coda_incremental.New_transition.observe new_block_incr
          in
          Coda_incremental.New_transition.stabilize () ;
          let frontier_new_block_reader =
            Coda_incremental.New_transition.to_pipe new_block_observer
          in
          Pipe.filter_map frontier_new_block_reader ~f:(fun new_block ->
              let unverified_new_block =
                External_transition.Validated.forget_validation new_block
              in
              Option.some_if
                (Public_key.Compressed.equal
                   (proposer unverified_new_block)
                   public_key)
                unverified_new_block ) )

    let new_payment coda public_key =
      let transaction_database = Program.transaction_database coda in
      global_pipe coda ~to_pipe:(fun new_block_incr ->
          let payments_incr =
            Coda_incremental.New_transition.map new_block_incr
              ~f:
                (Fn.compose payments
                   External_transition.Validated.forget_validation)
          in
          let payments_observer =
            Coda_incremental.New_transition.observe payments_incr
          in
          Coda_incremental.New_transition.stabilize () ;
          let frontier_payment_reader, frontier_payment_writer =
            (* TODO: capacity should be the max amount of transactions in a block *)
            Strict_pipe.(create (Buffered (`Capacity 20, `Overflow Drop_head)))
          in
          let write_user_commands user_commands =
            List.filter user_commands ~f:(fun user_command ->
                Public_key.Compressed.equal
                  (User_command.sender user_command)
                  public_key )
            |> List.iter ~f:(fun user_command ->
                   match User_command.check user_command with
                   | Some checked_user_command ->
                       Transaction_database.add transaction_database
                         (Coda_base.Transaction.User_command
                            checked_user_command) ;
                       Strict_pipe.Writer.write frontier_payment_writer
                         user_command
                   | None ->
                       let logger =
                         Logger.extend
                           (Program.top_level_logger coda)
                           [ ( "coda_command"
                             , `String "Checking user command failed" ) ]
                       in
                       Logger.error logger ~module_:__MODULE__
                         ~location:__LOC__
                         "Could not check user command correctly" )
          in
          Coda_incremental.New_transition.Observer.on_update_exn
            payments_observer ~f:(function
            | Initialized user_commands ->
                write_user_commands user_commands
            | Changed (_, user_commands) ->
                write_user_commands user_commands
            | Invalidated ->
                () ) ;
          (Strict_pipe.Reader.to_linear_pipe frontier_payment_reader)
            .Linear_pipe.Reader.pipe )
  end
end
