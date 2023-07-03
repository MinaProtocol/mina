open Core
open Async
open Pipe_lib
open Mina_base
open Mina_transaction
open Mina_state
open Mina_block

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

type Structured_log_events.t += Block_produced
  [@@deriving register_event { msg = "Successfully produced a new block" }]

let time_to_ms = Fn.compose Block_time.Span.to_ms Block_time.to_span_since_epoch

let time_of_ms = Fn.compose Block_time.of_span_since_epoch Block_time.Span.of_ms

(** Sends an error to the reporting service containing as many failed transactions as we can fit. *)
let report_transaction_inclusion_failures ~logger failed_txns =
  let num_failures = List.length failed_txns in
  let count_size = Fn.compose String.length Yojson.Safe.to_string in
  let wrap_error failed_txns_json =
    `Assoc
      [ ( "message"
        , `String
            "Some transactions failed to apply to the ledger when creating the \
             staged ledger diff" )
      ; ("num_failures", `Int num_failures)
      ; ("sampled_failures", failed_txns_json)
      ]
  in
  let rec generate_errors failures available_bytes =
    if available_bytes <= 0 then []
    else
      match failures with
      | [] ->
          []
      | (txn, error) :: remaining_failures ->
          let element =
            `Assoc
              [ ("transaction", User_command.Valid.to_yojson txn)
              ; ("error", Error_json.error_to_yojson error)
              ]
          in
          let element_size = count_size element in
          (* subtract an additional byte for each element here to account for commas *)
          element
          :: generate_errors remaining_failures
               (available_bytes - element_size - 1)
  in
  Node_error_service.send_dynamic_report ~logger
    ~generate_error:(fun available_bytes ->
      (* subtract 2 bytes to account for empty string *)
      let base_error_size = count_size (wrap_error (`String "")) - 2 in
      (* subtract 2 bytes to account for list brackets that wrap failed_txns *)
      let leftover_bytes = available_bytes - base_error_size - 2 in
      wrap_error (`List (generate_errors failed_txns leftover_bytes)) )

let generate_next_state ~constraint_constants ~previous_protocol_state
    ~time_controller ~staged_ledger ~transactions ~get_completed_work ~logger
    ~(block_data : Consensus.Data.Block_data.t) ~winner_pk ~scheduled_time
    ~log_block_creation ~block_reward_threshold =
  let previous_protocol_state_body_hash =
    Protocol_state.body previous_protocol_state |> Protocol_state.Body.hash
  in
  let previous_protocol_state_hash =
    (Protocol_state.hashes_with_body
       ~body_hash:previous_protocol_state_body_hash previous_protocol_state )
      .state_hash
  in
  let previous_state_view =
    Protocol_state.body previous_protocol_state
    |> Mina_state.Protocol_state.Body.view
  in
  let global_slot =
    Consensus.Data.Block_data.global_slot_since_genesis block_data
  in
  let supercharge_coinbase =
    let epoch_ledger = Consensus.Data.Block_data.epoch_ledger block_data in
    Staged_ledger.can_apply_supercharged_coinbase_exn ~winner:winner_pk
      ~epoch_ledger ~global_slot
  in
  let%map res =
    let coinbase_receiver =
      Consensus.Data.Block_data.coinbase_receiver block_data
    in
    let diff =
      O1trace.sync_thread "create_staged_ledger_diff" (fun () ->
          [%log internal] "Create_staged_ledger_diff" ;
          (* TODO: handle transaction inclusion failures here *)
          let diff_result =
            Staged_ledger.create_diff ~constraint_constants ~global_slot
              staged_ledger ~coinbase_receiver ~logger
              ~current_state_view:previous_state_view
              ~transactions_by_fee:transactions ~get_completed_work
              ~log_block_creation ~supercharge_coinbase
            |> Result.map ~f:(fun (diff, failed_txns) ->
                   if not (List.is_empty failed_txns) then
                     don't_wait_for
                       (report_transaction_inclusion_failures ~logger
                          failed_txns ) ;
                   diff )
            |> Result.map_error ~f:(fun err ->
                   Staged_ledger.Staged_ledger_error.Pre_diff err )
          in
          [%log internal] "Create_staged_ledger_diff_done" ;
          match (diff_result, block_reward_threshold) with
          | Ok diff, Some threshold ->
              let net_return =
                Option.value ~default:Currency.Amount.zero
                  (Staged_ledger_diff.net_return ~constraint_constants
                     ~supercharge_coinbase
                     (Staged_ledger_diff.forget diff) )
              in
              if Currency.Amount.(net_return >= threshold) then diff_result
              else (
                [%log info]
                  "Block reward $reward is less than the min-block-reward \
                   $threshold, creating empty block"
                  ~metadata:
                    [ ("threshold", Currency.Amount.to_yojson threshold)
                    ; ("reward", Currency.Amount.to_yojson net_return)
                    ] ;
                Ok
                  Staged_ledger_diff.With_valid_signatures_and_proofs.empty_diff
                )
          | _ ->
              diff_result )
    in
    [%log internal] "Apply_staged_ledger_diff" ;
    match%map
      let%bind.Deferred.Result diff = return diff in
      Staged_ledger.apply_diff_unchecked staged_ledger ~constraint_constants
        ~global_slot diff ~logger ~current_state_view:previous_state_view
        ~state_and_body_hash:
          (previous_protocol_state_hash, previous_protocol_state_body_hash)
        ~coinbase_receiver ~supercharge_coinbase
    with
    | Ok
        ( `Hash_after_applying next_staged_ledger_hash
        , `Ledger_proof ledger_proof_opt
        , `Staged_ledger transitioned_staged_ledger
        , `Pending_coinbase_update (is_new_stack, pending_coinbase_update) ) ->
        (*staged_ledger remains unchanged and transitioned_staged_ledger is discarded because the external transtion created out of this diff will be applied in Transition_frontier*)
        ignore
        @@ Mina_ledger.Ledger.unregister_mask_exn ~loc:__LOC__
             (Staged_ledger.ledger transitioned_staged_ledger) ;
        Some
          ( (match diff with Ok diff -> diff | Error _ -> assert false)
          , next_staged_ledger_hash
          , ledger_proof_opt
          , is_new_stack
          , pending_coinbase_update )
    | Error (Staged_ledger.Staged_ledger_error.Unexpected e) ->
        [%log error] "Failed to apply the diff: $error"
          ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
        None
    | Error e ->
        ( match diff with
        | Ok diff ->
            [%log error]
              ~metadata:
                [ ( "error"
                  , `String (Staged_ledger.Staged_ledger_error.to_string e) )
                ; ( "diff"
                  , Staged_ledger_diff.With_valid_signatures_and_proofs
                    .to_yojson diff )
                ]
              "Error applying the diff $diff: $error"
        | Error e ->
            [%log error] "Error building the diff: $error"
              ~metadata:
                [ ( "error"
                  , `String (Staged_ledger.Staged_ledger_error.to_string e) )
                ] ) ;
        None
  in
  [%log internal] "Apply_staged_ledger_diff_done" ;
  match res with
  | None ->
      None
  | Some
      ( diff
      , next_staged_ledger_hash
      , ledger_proof_opt
      , is_new_stack
      , pending_coinbase_update ) ->
      let protocol_state, consensus_transition_data =
        let previous_ledger_hash =
          previous_protocol_state |> Protocol_state.blockchain_state
          |> Blockchain_state.snarked_ledger_hash
        in
        let ledger_proof_statement =
          match ledger_proof_opt with
          | Some (proof, _) ->
              Ledger_proof.statement proof
          | None ->
              let state =
                previous_protocol_state |> Protocol_state.blockchain_state
              in
              Blockchain_state.ledger_proof_statement state
        in
        let genesis_ledger_hash =
          previous_protocol_state |> Protocol_state.blockchain_state
          |> Blockchain_state.genesis_ledger_hash
        in
        let supply_increase =
          Option.value_map ledger_proof_opt
            ~f:(fun (proof, _) -> (Ledger_proof.statement proof).supply_increase)
            ~default:Currency.Amount.Signed.zero
        in
        let body_reference =
          Staged_ledger_diff.Body.compute_reference
            (Body.create @@ Staged_ledger_diff.forget diff)
        in
        let blockchain_state =
          (* We use the time of the beginning of the slot because if things
             are slower than expected, we may have entered the next slot and
             putting the **current** timestamp rather than the expected one
             will screw things up.

             [generate_transition] will log an error if the [current_time]
             has a different slot from the [scheduled_time]
          *)
          Blockchain_state.create_value ~timestamp:scheduled_time
            ~genesis_ledger_hash ~staged_ledger_hash:next_staged_ledger_hash
            ~body_reference ~ledger_proof_statement
        in
        let current_time =
          Block_time.now time_controller
          |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
        in
        O1trace.sync_thread "generate_consensus_transition" (fun () ->
            Consensus_state_hooks.generate_transition ~previous_protocol_state
              ~blockchain_state ~current_time ~block_data ~supercharge_coinbase
              ~snarked_ledger_hash:previous_ledger_hash ~genesis_ledger_hash
              ~supply_increase ~logger ~constraint_constants )
      in
      let snark_transition =
        O1trace.sync_thread "generate_snark_transition" (fun () ->
            Snark_transition.create_value
              ~blockchain_state:(Protocol_state.blockchain_state protocol_state)
              ~consensus_transition:consensus_transition_data
              ~pending_coinbase_update () )
      in
      let internal_transition =
        O1trace.sync_thread "generate_internal_transition" (fun () ->
            Internal_transition.create ~snark_transition
              ~prover_state:(Consensus.Data.Block_data.prover_state block_data)
              ~staged_ledger_diff:(Staged_ledger_diff.forget diff)
              ~ledger_proof:
                (Option.map ledger_proof_opt ~f:(fun (proof, _) -> proof)) )
      in
      let witness =
        { Pending_coinbase_witness.pending_coinbases =
            Staged_ledger.pending_coinbase_collection staged_ledger
        ; is_new_stack
        }
      in
      Some (protocol_state, internal_transition, witness)

module Precomputed = struct
  type t = Precomputed.t =
    { scheduled_time : Block_time.t
    ; protocol_state : Protocol_state.value
    ; protocol_state_proof : Proof.t
    ; staged_ledger_diff : Staged_ledger_diff.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.t * Frozen_ledger_hash.t list
    ; protocol_version : Protocol_version.t
    ; proposed_protocol_version : Protocol_version.t option
    ; accounts_accessed : (int * Account.t) list
    ; accounts_created : (Account_id.t * Currency.Fee.t) list
    ; tokens_used : (Token_id.t * Account_id.t option) list
    }

  let sexp_of_t = Precomputed.sexp_of_t

  let t_of_sexp = Precomputed.t_of_sexp
end

let handle_block_production_errors ~logger ~rejected_blocks_logger
    ~time_taken:span ~previous_protocol_state ~protocol_state x =
  let transition_error_msg_prefix = "Validation failed: " in
  let transition_reason_for_failure =
    " One possible reason could be a ledger-catchup is triggered before we \
     produce a proof for the produced transition."
  in
  let exn_breadcrumb err =
    Error.tag err ~tag:"Error building breadcrumb from produced transition"
    |> Error.raise
  in
  let time_metadata =
    ("time", `Int (Block_time.Span.to_ms span |> Int64.to_int_exn))
  in
  let state_metadata =
    ("protocol_state", Protocol_state.Value.to_yojson protocol_state)
  in
  match x with
  | Ok x ->
      return x
  | Error
      (`Prover_error
        ( err
        , ( previous_protocol_state_proof
          , internal_transition
          , pending_coinbase_witness ) ) ) ->
      let msg : (_, unit, string, unit) format4 =
        "Prover failed to prove freshly generated transition: $error"
      in
      let metadata =
        [ ("error", Error_json.error_to_yojson err)
        ; ("prev_state", Protocol_state.value_to_yojson previous_protocol_state)
        ; ("prev_state_proof", Proof.to_yojson previous_protocol_state_proof)
        ; ("next_state", Protocol_state.value_to_yojson protocol_state)
        ; ( "internal_transition"
          , Internal_transition.to_yojson internal_transition )
        ; ( "pending_coinbase_witness"
          , Pending_coinbase_witness.to_yojson pending_coinbase_witness )
        ; time_metadata
        ]
      in
      [%log error] ~metadata msg ;
      [%log' debug rejected_blocks_logger] ~metadata msg ;
      return ()
  | Error `Invalid_genesis_protocol_state ->
      let state_yojson =
        Fn.compose State_hash.to_yojson Protocol_state.genesis_state_hash
      in
      let msg : (_, unit, string, unit) format4 =
        "Produced transition has invalid genesis state hash"
      in
      let metadata =
        [ ("expected", state_yojson previous_protocol_state)
        ; ("got", state_yojson protocol_state)
        ]
      in
      [%log warn] ~metadata msg ;
      [%log' debug rejected_blocks_logger]
        ~metadata:([ time_metadata; state_metadata ] @ metadata)
        msg ;
      return ()
  | Error `Already_in_frontier ->
      let metadata = [ time_metadata; state_metadata ] in
      [%log error] ~metadata "%sproduced transition is already in frontier"
        transition_error_msg_prefix ;
      [%log' debug rejected_blocks_logger]
        ~metadata "%sproduced transition is already in frontier"
        transition_error_msg_prefix ;
      return ()
  | Error `Not_selected_over_frontier_root ->
      let metadata = [ time_metadata; state_metadata ] in
      [%log warn] ~metadata
        "%sproduced transition is not selected over the root of transition \
         frontier.%s"
        transition_error_msg_prefix transition_reason_for_failure ;
      [%log' debug rejected_blocks_logger]
        ~metadata
        "%sproduced transition is not selected over the root of transition \
         frontier.%s"
        transition_error_msg_prefix transition_reason_for_failure ;
      return ()
  | Error `Parent_missing_from_frontier ->
      let metadata = [ time_metadata; state_metadata ] in
      [%log warn] ~metadata
        "%sparent of produced transition is missing from the frontier.%s"
        transition_error_msg_prefix transition_reason_for_failure ;
      [%log' debug rejected_blocks_logger]
        ~metadata
        "%sparent of produced transition is missing from the frontier.%s"
        transition_error_msg_prefix transition_reason_for_failure ;
      return ()
  | Error (`Fatal_error e) ->
      exn_breadcrumb (Error.tag ~tag:"Fatal error" (Error.of_exn e))
  | Error (`Invalid_staged_ledger_hash e) ->
      exn_breadcrumb (Error.tag ~tag:"Invalid staged ledger hash" e)
  | Error (`Invalid_staged_ledger_diff (e, staged_ledger_diff)) ->
      let msg : (_, unit, string, unit) format4 =
        "Unable to build breadcrumb from produced transition due to invalid \
         staged ledger diff: $error"
      in
      let metadata =
        [ ("error", Error_json.error_to_yojson e)
        ; ("diff", Staged_ledger_diff.to_yojson staged_ledger_diff)
        ]
      in
      [%log error] ~metadata msg ;
      [%log' debug rejected_blocks_logger]
        ~metadata:([ time_metadata; state_metadata ] @ metadata)
        msg ;
      return ()

let time ~logger ~time_controller label f =
  let open Deferred.Result.Let_syntax in
  let t0 = Block_time.now time_controller in
  let%map x = f () in
  let span = Block_time.diff (Block_time.now time_controller) t0 in
  [%log info]
    ~metadata:
      [ ("time", `Int (Block_time.Span.to_ms span |> Int64.to_int_exn)) ]
    !"%s: $time %!" label ;
  x

let retry ?(max = 3) ~logger ~error_message f =
  let rec go n =
    if n >= max then failwith error_message
    else
      match%bind f () with
      | Error e ->
          [%log error] "%s : $error. Trying again" error_message
            ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ;
          go (n + 1)
      | Ok res ->
          return res
  in
  go 0

module Vrf_evaluation_state = struct
  type status =
    | At of Mina_numbers.Global_slot_since_hard_fork.t
    | Start
    | Completed

  type t =
    { queue : Consensus.Data.Slot_won.t Queue.t
    ; mutable vrf_evaluator_status : status
    }

  let poll_vrf_evaluator ~logger vrf_evaluator =
    let f () =
      O1trace.thread "query_vrf_evaluator" (fun () ->
          Vrf_evaluator.slots_won_so_far vrf_evaluator )
    in
    retry ~logger ~error_message:"Error fetching slots from the VRF evaluator" f

  let create () = { queue = Core.Queue.create (); vrf_evaluator_status = Start }

  let finished t =
    match t.vrf_evaluator_status with Completed -> true | _ -> false

  let evaluator_status t = t.vrf_evaluator_status

  let update_status t (vrf_status : Vrf_evaluator.Evaluator_status.t) =
    match vrf_status with
    | At global_slot ->
        t.vrf_evaluator_status <- At global_slot
    | Completed ->
        t.vrf_evaluator_status <- Completed

  let poll ~vrf_evaluator ~logger t =
    [%log info] "Polling VRF evaluator process" ;
    let%bind vrf_result = poll_vrf_evaluator vrf_evaluator ~logger in
    let%map vrf_result =
      match (vrf_result.evaluator_status, vrf_result.slots_won) with
      | At _, [] ->
          (*try again*)
          let%bind () =
            Async.after
              (Time.Span.of_ms
                 (Mina_compile_config.vrf_poll_interval_ms |> Int.to_float) )
          in
          poll_vrf_evaluator vrf_evaluator ~logger
      | _ ->
          return vrf_result
    in
    Queue.enqueue_all t.queue vrf_result.slots_won ;
    update_status t vrf_result.evaluator_status ;
    [%log info]
      !"New global slots won: $slots"
      ~metadata:
        [ ( "slots"
          , `List
              (List.map vrf_result.slots_won ~f:(fun s ->
                   Mina_numbers.Global_slot_since_hard_fork.to_yojson
                     s.global_slot ) ) )
        ]

  let update_epoch_data ~vrf_evaluator ~logger ~epoch_data_for_vrf t =
    let set_epoch_data () =
      let f () =
        O1trace.thread "set_vrf_evaluator_epoch_state" (fun () ->
            Vrf_evaluator.set_new_epoch_state vrf_evaluator ~epoch_data_for_vrf )
      in
      retry ~logger
        ~error_message:"Error setting epoch state of the VRF evaluator" f
    in
    [%log info] "Sending data for VRF evaluations for epoch $epoch"
      ~metadata:
        [ ("epoch", Mina_numbers.Length.to_yojson epoch_data_for_vrf.epoch) ] ;
    t.vrf_evaluator_status <- Start ;
    let%bind () = set_epoch_data () in
    poll ~logger ~vrf_evaluator t
end

let log_bootstrap_mode ~logger () =
  [%log info] "Pausing block production while bootstrapping"

let genesis_breadcrumb_creator ~context:(module Context : CONTEXT) prover =
  let open Context in
  let started = ref false in
  let genesis_breadcrumb_ivar = Ivar.create () in
  fun () ->
    if !started then Ivar.read genesis_breadcrumb_ivar
    else
      O1trace.thread "genesis_breadcrumb_creator"
      @@ fun () ->
      started := true ;
      let max_num_retries = 3 in
      let rec go retries =
        [%log info]
          "Generating genesis proof ($attempts_remaining / $max_attempts)"
          ~metadata:
            [ ("attempts_remaining", `Int retries)
            ; ("max_attempts", `Int max_num_retries)
            ] ;
        match%bind
          Prover.create_genesis_block prover
            (Genesis_proof.to_inputs precomputed_values)
        with
        | Ok res ->
            Ivar.fill genesis_breadcrumb_ivar (Ok res) ;
            return (Ok res)
        | Error err ->
            [%log error] "Failed to generate genesis breadcrumb: $error"
              ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
            if retries > 0 then go (retries - 1)
            else (
              Ivar.fill genesis_breadcrumb_ivar (Error err) ;
              return (Error err) )
      in
      go max_num_retries

let produce ~genesis_breadcrumb ~context:(module Context : CONTEXT) ~prover
    ~verifier ~trust_system ~get_completed_work ~transaction_resource_pool
    ~frontier ~time_controller ~transition_writer ~log_block_creation
    ~block_reward_threshold ~block_produced_bvar ~wait_for_finalization
    (scheduled_time, block_data, winner_pubkey) =
  O1trace.thread "produce"
  @@ fun () ->
  let module Breadcrumb = Transition_frontier.Breadcrumb in
  let open Context in
  let rejected_blocks_logger =
    Logger.create ~id:Logger.Logger_id.rejected_blocks ()
  in
  let global_slot =
    Consensus.Data.Block_data.global_slot_since_genesis block_data
  in
  Internal_tracing.with_slot global_slot
  @@ fun () ->
  [%log internal] "Begin_block_production" ;
  let crumb = Transition_frontier.best_tip frontier in
  let crumb =
    O1trace.sync_thread "produce_sync_1"
    @@ fun () ->
    let crumb_global_slot_since_genesis =
      Breadcrumb.protocol_state crumb
      |> Protocol_state.consensus_state
      |> Consensus.Data.Consensus_state.global_slot_since_genesis
    in
    let block_global_slot_since_genesis =
      Consensus.Proof_of_stake.Data.Block_data.global_slot_since_genesis
        block_data
    in
    if
      Mina_numbers.Global_slot_since_genesis.equal
        crumb_global_slot_since_genesis block_global_slot_since_genesis
    then
      (* We received a block for this slot over the network before
         attempting to produce our own. Build upon its parent instead
         of attempting (and failing) to build upon the block itself.
      *)
      Transition_frontier.find_exn frontier (Breadcrumb.parent_hash crumb)
    else crumb
  in
  let start = Block_time.now time_controller in
  [%log info]
    ~metadata:[ ("breadcrumb", Breadcrumb.to_yojson crumb) ]
    "Producing new block with parent $breadcrumb%!" ;
  let previous_transition = Breadcrumb.block_with_hash crumb in
  let previous_protocol_state =
    Header.protocol_state
    @@ Mina_block.header (With_hash.data previous_transition)
  in
  let%bind previous_protocol_state_proof =
    O1trace.thread "produce_1"
    @@ fun () ->
    if
      Consensus.Data.Consensus_state.is_genesis_state
        (Protocol_state.consensus_state previous_protocol_state)
      && Option.is_none precomputed_values.proof_data
    then (
      match%bind genesis_breadcrumb () with
      | Ok block ->
          return @@ Blockchain_snark.Blockchain.proof block
      | Error _ ->
          [%log error]
            "Aborting block production: cannot generate a genesis proof" ;
          Deferred.never () )
    else
      return
        ( Header.protocol_state_proof
        @@ Mina_block.header (With_hash.data previous_transition) )
  in
  [%log internal] "Get_transactions_from_pool" ;
  let transactions =
    Network_pool.Transaction_pool.Resource_pool.transactions
      transaction_resource_pool
    |> Sequence.map ~f:Transaction_hash.User_command_with_valid_signature.data
  in
  [%log internal] "Generate_next_state" ;
  let%bind next_state_opt =
    O1trace.thread "produce_2"
    @@ fun () ->
    generate_next_state ~constraint_constants ~scheduled_time ~block_data
      ~previous_protocol_state ~time_controller
      ~staged_ledger:(Breadcrumb.staged_ledger crumb)
      ~transactions ~get_completed_work ~logger ~log_block_creation
      ~winner_pk:winner_pubkey ~block_reward_threshold
  in
  [%log internal] "Generate_next_state_done" ;
  match next_state_opt with
  | None ->
      return ()
  | Some (protocol_state, internal_transition, pending_coinbase_witness) ->
      let diff = Internal_transition.staged_ledger_diff internal_transition in
      let commands = Staged_ledger_diff.commands diff in
      let transactions_count = List.length commands in
      let protocol_state_hashes = Protocol_state.hashes protocol_state in
      let consensus_state_with_hashes =
        { With_hash.hash = protocol_state_hashes
        ; data = Protocol_state.consensus_state protocol_state
        }
      in
      [%log internal] "@produced_block_state_hash"
        ~metadata:
          [ ( "state_hash"
            , `String
                (Mina_base.State_hash.to_base58_check
                   protocol_state_hashes.state_hash ) )
          ] ;
      Internal_tracing.with_state_hash protocol_state_hashes.state_hash
      @@ fun () ->
      Debug_assert.debug_assert (fun () ->
          O1trace.sync_thread "produce_sync_2"
          @@ fun () ->
          [%test_result: [ `Take | `Keep ]]
            (Consensus.Hooks.select
               ~context:(module Context)
               ~existing:
                 (With_hash.map ~f:Mina_block.consensus_state
                    previous_transition )
               ~candidate:consensus_state_with_hashes )
            ~expect:`Take
            ~message:
              "newly generated consensus states should be selected over their \
               parent" ;
          let root_consensus_state_with_hashes =
            Transition_frontier.root frontier
            |> Breadcrumb.consensus_state_with_hashes
          in
          [%test_result: [ `Take | `Keep ]]
            (Consensus.Hooks.select
               ~context:(module Context)
               ~existing:root_consensus_state_with_hashes
               ~candidate:consensus_state_with_hashes )
            ~expect:`Take
            ~message:
              "newly generated consensus states should be selected over the tf \
               root" ) ;
      let emit_breadcrumb () =
        O1trace.thread "produce_3"
        @@ fun () ->
        let open Deferred.Result.Let_syntax in
        [%log internal]
          ~metadata:[ ("transactions_count", `Int transactions_count) ]
          "Produce_state_transition_proof" ;
        let%bind protocol_state_proof =
          time ~logger ~time_controller "Protocol_state_proof proving time(ms)"
            (fun () ->
              O1trace.thread "dispatch_block_proving" (fun () ->
                  Prover.prove prover ~prev_state:previous_protocol_state
                    ~prev_state_proof:previous_protocol_state_proof
                    ~next_state:protocol_state internal_transition
                    pending_coinbase_witness )
              |> Deferred.Result.map_error ~f:(fun err ->
                     `Prover_error
                       ( err
                       , ( previous_protocol_state_proof
                         , internal_transition
                         , pending_coinbase_witness ) ) ) )
        in
        let staged_ledger_diff =
          Internal_transition.staged_ledger_diff internal_transition
        in
        let previous_state_hash =
          (Protocol_state.hashes previous_protocol_state).state_hash
        in
        [%log internal] "Produce_chain_transition_proof" ;
        let delta_block_chain_proof =
          O1trace.sync_thread "produce_sync_3"
          @@ fun () ->
          Transition_chain_prover.prove
            ~length:(Mina_numbers.Length.to_int consensus_constants.delta)
            ~frontier previous_state_hash
          |> Option.value_exn
        in
        [%log internal] "Produce_validated_transition" ;
        let%bind transition =
          O1trace.thread "produce_4"
          @@ fun () ->
          let open Result.Let_syntax in
          Validation.wrap
            { With_hash.hash = protocol_state_hashes
            ; data =
                (let body = Body.create staged_ledger_diff in
                 Mina_block.create ~body
                   ~header:
                     (Header.create ~protocol_state ~protocol_state_proof
                        ~delta_block_chain_proof () ) )
            }
          |> Validation.skip_time_received_validation
               `This_block_was_not_received_via_gossip
          |> Validation.skip_protocol_versions_validation
               `This_block_has_valid_protocol_versions
          |> Validation.validate_genesis_protocol_state
               ~genesis_state_hash:
                 (Protocol_state.genesis_state_hash
                    ~state_hash:(Some previous_state_hash)
                    previous_protocol_state )
          >>| Validation.skip_proof_validation
                `This_block_was_generated_internally
          >>| Validation.skip_delta_block_chain_validation
                `This_block_was_not_received_via_gossip
          >>= Validation.validate_frontier_dependencies
                ~context:(module Context)
                ~root_block:
                  ( Transition_frontier.root frontier
                  |> Breadcrumb.block_with_hash )
                ~get_block_by_hash:
                  (Fn.compose
                     (Option.map ~f:Breadcrumb.block_with_hash)
                     (Transition_frontier.find frontier) )
          |> Deferred.return
        in
        let transition_receipt_time = Some (Time.now ()) in
        let%bind breadcrumb =
          O1trace.thread "produce_5"
          @@ fun () ->
          time ~logger ~time_controller "Build breadcrumb on produced block"
            (fun () ->
              Breadcrumb.build ~logger ~precomputed_values ~verifier
                ~get_completed_work:(Fn.const None) ~trust_system ~parent:crumb
                ~transition ~sender:None (* Consider skipping `All here *)
                ~skip_staged_ledger_verification:`Proofs
                ~transition_receipt_time () )
          |> Deferred.Result.map_error ~f:(function
               | `Invalid_staged_ledger_diff e ->
                   `Invalid_staged_ledger_diff (e, staged_ledger_diff)
               | ( `Fatal_error _
                 | `Invalid_genesis_protocol_state
                 | `Invalid_staged_ledger_hash _
                 | `Not_selected_over_frontier_root
                 | `Parent_missing_from_frontier
                 | `Prover_error _ ) as err ->
                   err )
        in
        O1trace.sync_thread "produce_sync_4"
        @@ fun () ->
        let txs =
          Mina_block.transactions ~constraint_constants
            (Breadcrumb.block breadcrumb)
          |> List.map ~f:Transaction.yojson_summary_with_status
        in
        [%log internal] "@block_metadata"
          ~metadata:
            [ ( "blockchain_length"
              , Mina_numbers.Length.to_yojson @@ Mina_block.blockchain_length
                @@ Breadcrumb.block breadcrumb )
            ; ("transactions", `List txs)
            ] ;
        [%str_log info]
          ~metadata:[ ("breadcrumb", Breadcrumb.to_yojson breadcrumb) ]
          Block_produced ;
        (* let uptime service (and any other waiters) know about breadcrumb *)
        Bvar.broadcast block_produced_bvar breadcrumb ;
        Mina_metrics.(Counter.inc_one Block_producer.blocks_produced) ;
        Mina_metrics.Block_producer.(
          Block_production_delay_histogram.observe block_production_delay
            Time.(
              Span.to_ms
              @@ diff (now ())
              @@ Block_time.to_time_exn scheduled_time)) ;
        [%log internal] "Send_breadcrumb_to_transition_frontier" ;
        let%bind.Async.Deferred () =
          O1trace.thread "produce_6"
          @@ fun () -> Strict_pipe.Writer.write transition_writer breadcrumb
        in
        let metadata =
          [ ("state_hash", State_hash.to_yojson protocol_state_hashes.state_hash)
          ]
        in
        [%log internal] "Wait_for_confirmation" ;
        [%log debug] ~metadata
          "Waiting for block $state_hash to be inserted into frontier" ;
        O1trace.thread "produce_7"
        @@ fun () ->
        (* We allow up to 20 seconds for the transition
           to make its way from the transition_writer to
           the frontier.
           This value is chosen to be reasonably
           generous. In theory, this should not take
           terribly long. But long cycles do happen in
           our system, and with medium curves those long
           cycles can be substantial.
        *)
        match%bind.Deferred
          wait_for_finalization
            (Time_ns.Span.of_int_sec 20)
            (Breadcrumb.block_with_hash breadcrumb)
        with
        | `Transition_accepted ->
            [%log internal] "Transition_accepted" ;
            [%log info] ~metadata
              "Generated transition $state_hash was accepted into transition \
               frontier" ;
            return ()
        | `Timed_out ->
            (* FIXME #3167: this should be fatal, and more
               importantly, shouldn't happen.
            *)
            [%log internal] "Transition_accept_timeout" ;
            let msg : (_, unit, string, unit) format4 =
              "Timed out waiting for generated transition $state_hash to enter \
               transition frontier. Continuing to produce new blocks anyway. \
               This may mean your CPU is overloaded. Consider disabling \
               `-run-snark-worker` if it's configured."
            in
            let span = Block_time.diff (Block_time.now time_controller) start in
            let metadata =
              [ ("time", `Int (Block_time.Span.to_ms span |> Int64.to_int_exn))
              ; ("protocol_state", Protocol_state.Value.to_yojson protocol_state)
              ]
              @ metadata
            in
            [%log' debug rejected_blocks_logger] ~metadata msg ;
            [%log fatal] ~metadata msg ;
            return ()
      in
      let%bind res = emit_breadcrumb () in
      O1trace.sync_thread "produce_sync_5"
      @@ fun () ->
      let span = Block_time.diff (Block_time.now time_controller) start in
      handle_block_production_errors ~logger ~rejected_blocks_logger
        ~time_taken:span ~previous_protocol_state ~protocol_state res

let iteration ~schedule_next_check ~dispatch_now ~schedule_dispatch
    ~next_check_now ~context:(module Context : CONTEXT) ~vrf_evaluator
    ~time_controller ~coinbase_receiver ~set_next_producer_timing ~frontier
    ~vrf_evaluation_state ~epoch_data_for_vrf ~ledger_snapshot i slot =
  O1trace.thread
    ( "block_producer_iteration "
    ^ Unsigned.UInt32.to_string i
    ^ " "
    ^ Mina_numbers.Global_slot_since_hard_fork.to_string slot )
  @@ fun () ->
  let consensus_state =
    Transition_frontier.(best_tip frontier |> Breadcrumb.consensus_state)
  in
  O1trace.thread "bp_0"
  @@ fun () ->
  let i' =
    Mina_numbers.Length.succ
      epoch_data_for_vrf.Consensus.Data.Epoch_data_for_vrf.epoch
  in
  O1trace.thread "bp_1"
  @@ fun () ->
  let new_global_slot = epoch_data_for_vrf.global_slot in
  let open Context in
  let%bind () =
    if Mina_numbers.Length.(i' > i) then
      Vrf_evaluation_state.update_epoch_data ~vrf_evaluator ~epoch_data_for_vrf
        ~logger vrf_evaluation_state
    else Deferred.unit
  in
  O1trace.thread "bp_2"
  @@ fun () ->
  let%bind () =
    (*Poll once every slot if the evaluation for the epoch is not completed or the evaluation is completed*)
    if
      Mina_numbers.Global_slot_since_hard_fork.(new_global_slot > slot)
      && not (Vrf_evaluation_state.finished vrf_evaluation_state)
    then Vrf_evaluation_state.poll ~vrf_evaluator ~logger vrf_evaluation_state
    else Deferred.unit
  in
  O1trace.thread "bp_3"
  @@ fun () ->
  match Core.Queue.dequeue vrf_evaluation_state.queue with
  | None -> (
      O1trace.thread "bp_4"
      @@ fun () ->
      (*Keep trying until we get some slots*)
      let poll () =
        let%bind () =
          Async.after
            (Time.Span.of_ms
               (Mina_compile_config.vrf_poll_interval_ms |> Int.to_float) )
        in
        let%bind () =
          Vrf_evaluation_state.poll ~vrf_evaluator ~logger vrf_evaluation_state
        in
        schedule_next_check (Block_time.now time_controller)
      in
      match Vrf_evaluation_state.evaluator_status vrf_evaluation_state with
      | Completed ->
          let epoch_end_time =
            Consensus.Hooks.epoch_end_time ~constants:consensus_constants
              epoch_data_for_vrf.epoch
          in
          set_next_producer_timing (`Check_again epoch_end_time) consensus_state ;
          [%log info] "No more slots won in this epoch" ;
          schedule_next_check epoch_end_time
      | At last_slot ->
          set_next_producer_timing (`Evaluating_vrf last_slot) consensus_state ;
          O1trace.thread "block_producer_iteration: poll 1" @@ fun () -> poll ()
      | Start ->
          set_next_producer_timing (`Evaluating_vrf new_global_slot)
            consensus_state ;
          O1trace.thread "block_producer_iteration: poll 2" @@ fun () -> poll ()
      )
  | Some slot_won -> (
      O1trace.thread "bp_5"
      @@ fun () ->
      let winning_global_slot = slot_won.global_slot in
      let slot, epoch =
        let t =
          Consensus.Data.Consensus_time.of_global_slot winning_global_slot
            ~constants:consensus_constants
        in
        Consensus.Data.Consensus_time.(slot t, epoch t)
      in
      [%log info] "Block producer won slot $slot in epoch $epoch"
        ~metadata:
          [ ( "slot"
            , Mina_numbers.Global_slot_since_genesis.(
                to_yojson @@ of_uint32 slot) )
          ; ("epoch", Mina_numbers.Length.to_yojson epoch)
          ] ;
      O1trace.thread "bp_6"
      @@ fun () ->
      let now = Block_time.now time_controller in
      let curr_global_slot =
        Consensus.Data.Consensus_time.(
          of_time_exn ~constants:consensus_constants now |> to_global_slot)
      in
      let winner_pk = fst slot_won.delegator in
      let data =
        Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
          ~coinbase_receiver:!coinbase_receiver
      in
      if
        Mina_numbers.Global_slot_since_hard_fork.(
          curr_global_slot = winning_global_slot)
      then (
        O1trace.thread "bp_7"
        @@ fun () ->
        (*produce now*)
        [%log info] "Producing a block now" ;
        set_next_producer_timing
          (`Produce_now (data, winner_pk))
          consensus_state ;
        Mina_metrics.(Counter.inc_one Block_producer.slots_won) ;
        dispatch_now (now, data, winner_pk) )
      else
        O1trace.thread "bp_8"
        @@ fun () ->
        let global_slot_diff =
          O1trace.sync_thread "bp_sync_3"
          @@ fun () ->
          Mina_numbers.Global_slot_since_hard_fork.diff winning_global_slot
            curr_global_slot
        in
        match global_slot_diff with
        | None ->
            O1trace.thread "bp_9"
            @@ fun () ->
            [%log warn]
              "Skipping block production for global slot $slot_won because it \
               has passed. Current global slot is $curr_slot"
              ~metadata:
                [ ( "slot_won"
                  , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      winning_global_slot )
                ; ( "curr_slot"
                  , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      curr_global_slot )
                ] ;
            next_check_now ()
        | Some slot_diff ->
            O1trace.thread "bp_10"
            @@ fun () ->
            let time =
              O1trace.sync_thread "bp_sync_4"
              @@ fun () ->
              [%log info] "Producing a block in $slots slots"
                ~metadata:
                  [ ("slots", Mina_numbers.Global_slot_span.to_yojson slot_diff)
                  ] ;
              Consensus.Data.Consensus_time.(
                start_time ~constants:consensus_constants
                  (of_global_slot ~constants:consensus_constants
                     winning_global_slot ))
              |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
            in
            O1trace.sync_thread "bp_sync_5" (fun () ->
                set_next_producer_timing
                  (`Produce (time, data, winner_pk))
                  consensus_state ;
                Mina_metrics.(Counter.inc_one Block_producer.slots_won) ) ;
            let scheduled_time = time_of_ms time in
            schedule_dispatch (scheduled_time, data, winner_pk) )

let schedule ~logger ~time_controller time =
  O1trace.thread "block_producer_schedule"
  @@ fun () ->
  let span_till_time = Block_time.diff time (Block_time.now time_controller) in
  [%log info] "schedule: waiting for %s"
    (Block_time.Span.to_string_hum span_till_time) ;
  Block_time.Span.to_time_ns_span span_till_time
  |> Async_kernel.after
  >>| fun () ->
  [%log info] "schedule: ended waiting for %s"
    (Block_time.Span.to_string_hum span_till_time)

let run ~context:(module Context : CONTEXT) ~vrf_evaluator ~prover ~verifier
    ~trust_system ~get_completed_work ~transaction_resource_pool
    ~time_controller ~consensus_local_state ~coinbase_receiver ~frontier_reader
    ~transition_writer ~set_next_producer_timing ~log_block_creation
    ~block_reward_threshold ~block_produced_bvar ~vrf_evaluation_state
    ~wait_for_finalization =
  let open Context in
  O1trace.sync_thread "block_producer_run"
  @@ fun () ->
  let genesis_breadcrumb =
    genesis_breadcrumb_creator ~context:(module Context) prover
  in
  (* Wait for frontier to be initialized and pre-emptively create genesis if best tip is genesis
     This will only be executed on the very start of the network. Preemptive execution is needed
     to ensire first block creation won't be delayed. *)
  don't_wait_for
    ( O1trace.thread "create_genesis"
    @@ fun () ->
    Broadcast_pipe.Reader.iter_until frontier_reader ~f:(function
      | None ->
          return false
      | Some frontier ->
          let consensus_state =
            Transition_frontier.(
              best_tip frontier |> Breadcrumb.consensus_state)
          in
          let%map () =
            if Consensus.Data.Consensus_state.is_genesis_state consensus_state
            then genesis_breadcrumb () |> Deferred.ignore_m
            else Deferred.unit
          in
          true ) ) ;
  let module Breadcrumb = Transition_frontier.Breadcrumb in
  let iteration_wrapped (slot, i) =
    O1trace.thread "block_producer_iteration_wrapped"
    @@ fun () ->
    (* Begin checking for the ability to produce a block *)
    match Broadcast_pipe.Reader.peek frontier_reader with
    | None ->
        log_bootstrap_mode ~logger () ;
        let%map () =
          Broadcast_pipe.Reader.iter_until frontier_reader
            ~f:(Fn.compose Deferred.return Option.is_some)
        in
        (slot, i)
    | Some frontier ->
        let consensus_state =
          Transition_frontier.best_tip frontier |> Breadcrumb.consensus_state
        in
        let now = Block_time.now time_controller in
        let epoch_data_for_vrf, ledger_snapshot =
          O1trace.sync_thread "get_epoch_data_for_vrf" (fun () ->
              Consensus.Hooks.get_epoch_data_for_vrf
                ~constants:consensus_constants (time_to_ms now) consensus_state
                ~local_state:consensus_local_state ~logger )
        in
        let i' = Mina_numbers.Length.succ epoch_data_for_vrf.epoch in
        let new_global_slot = epoch_data_for_vrf.global_slot in
        (* TODO: Re-enable this assertion when it doesn't fail dev demos
         *       (see #5354)
         * assert (
                   Consensus.Hooks.required_local_state_sync
                    ~constants:consensus_constants ~consensus_state
                    ~local_state:consensus_local_state
                   = None ) ; *)
        let next_check_now () = return (new_global_slot, i') in
        let produce_do frontier =
          produce ~prover ~verifier ~trust_system ~get_completed_work
            ~transaction_resource_pool ~transition_writer ~log_block_creation
            ~block_reward_threshold ~block_produced_bvar ~genesis_breadcrumb
            ~context:(module Context)
            ~frontier ~time_controller ~wait_for_finalization
        in
        let dispatch_now data =
          produce_do frontier data >>| const (new_global_slot, i')
        in
        let schedule_next_check time =
          let%map () = schedule ~logger ~time_controller time in
          (new_global_slot, i')
        in
        let schedule_dispatch (time, data, winner) =
          let%bind () = schedule ~logger ~time_controller time in
          let%map () =
            match Broadcast_pipe.Reader.peek frontier_reader with
            | None ->
                Deferred.return @@ log_bootstrap_mode ~logger ()
            | Some frontier' ->
                produce_do frontier' (time, data, winner)
          in
          (new_global_slot, i')
        in
        iteration ~schedule_next_check ~dispatch_now ~schedule_dispatch
          ~next_check_now
          ~context:(module Context)
          ~vrf_evaluator ~time_controller ~coinbase_receiver
          ~set_next_producer_timing ~frontier ~vrf_evaluation_state
          ~epoch_data_for_vrf ~ledger_snapshot i slot
  in
  let start _ =
    Deferred.forever
      (Mina_numbers.Global_slot_since_hard_fork.zero, Mina_numbers.Length.zero)
      iteration_wrapped
  in
  let genesis_state_timestamp = consensus_constants.genesis_state_timestamp in
  (* if the producer starts before genesis, sleep until genesis *)
  let now = Block_time.now time_controller in
  if Block_time.( >= ) now genesis_state_timestamp then start ()
  else (
    [%log warn]
      ~metadata:
        [ ( "time_till_genesis"
          , `Int
              (Int64.to_int_exn
                 ( Block_time.Span.to_ms
                 @@ Block_time.diff genesis_state_timestamp now ) ) )
        ]
      "Node started before genesis: waiting $time_till_genesis milliseconds \
       before starting block producer" ;
    upon (schedule ~logger ~time_controller genesis_state_timestamp) start )

let run_precomputed ~context:(module Context : CONTEXT) ~verifier ~trust_system
    ~time_controller ~frontier_reader ~transition_writer ~precomputed_blocks
    ~wait_for_finalization =
  let open Context in
  let log_bootstrap_mode () =
    [%log info] "Pausing block production while bootstrapping"
  in
  let rejected_blocks_logger =
    Logger.create ~id:Logger.Logger_id.rejected_blocks ()
  in
  let start = Block_time.now time_controller in
  let module Breadcrumb = Transition_frontier.Breadcrumb in
  (* accounts_accessed, accounts_created, tokens_used are unused here
     those fields are in precomputed blocks to add to the
     archive db, they're not needed for replaying blocks
  *)
  let produce
      { Precomputed.scheduled_time
      ; protocol_state
      ; protocol_state_proof
      ; staged_ledger_diff
      ; delta_transition_chain_proof = delta_block_chain_proof
      ; protocol_version = _
      ; proposed_protocol_version = _
      ; accounts_accessed = _
      ; accounts_created = _
      ; tokens_used = _
      } =
    let protocol_state_hashes = Protocol_state.hashes protocol_state in
    let consensus_state_with_hashes =
      { With_hash.hash = protocol_state_hashes
      ; data = Protocol_state.consensus_state protocol_state
      }
    in
    match Broadcast_pipe.Reader.peek frontier_reader with
    | None ->
        log_bootstrap_mode () ; return ()
    | Some frontier ->
        let crumb = Transition_frontier.best_tip frontier in
        [%log trace]
          ~metadata:[ ("breadcrumb", Breadcrumb.to_yojson crumb) ]
          "Emitting precomputed block with parent $breadcrumb%!" ;
        let previous_transition = Breadcrumb.block_with_hash crumb in
        let previous_protocol_state =
          Header.protocol_state
          @@ Mina_block.header (With_hash.data previous_transition)
        in
        Debug_assert.debug_assert (fun () ->
            [%test_result: [ `Take | `Keep ]]
              (Consensus.Hooks.select
                 ~context:(module Context)
                 ~existing:
                   (With_hash.map ~f:Mina_block.consensus_state
                      previous_transition )
                 ~candidate:consensus_state_with_hashes )
              ~expect:`Take
              ~message:
                "newly generated consensus states should be selected over \
                 their parent" ;
            let root_consensus_state_with_hashes =
              Transition_frontier.root frontier
              |> Breadcrumb.consensus_state_with_hashes
            in
            [%test_result: [ `Take | `Keep ]]
              (Consensus.Hooks.select
                 ~context:(module Context)
                 ~existing:root_consensus_state_with_hashes
                 ~candidate:consensus_state_with_hashes )
              ~expect:`Take
              ~message:
                "newly generated consensus states should be selected over the \
                 tf root" ) ;
        let emit_breadcrumb () =
          let open Deferred.Result.Let_syntax in
          let previous_protocol_state_hash =
            State_hash.With_state_hashes.state_hash previous_transition
          in
          let%bind transition =
            let open Result.Let_syntax in
            Validation.wrap
              { With_hash.hash = protocol_state_hashes
              ; data =
                  (let body = Body.create staged_ledger_diff in
                   Mina_block.create ~body
                     ~header:
                       (Header.create ~protocol_state ~protocol_state_proof
                          ~delta_block_chain_proof () ) )
              }
            |> Validation.skip_time_received_validation
                 `This_block_was_not_received_via_gossip
            |> Validation.skip_protocol_versions_validation
                 `This_block_has_valid_protocol_versions
            |> Validation.skip_proof_validation
                 `This_block_was_generated_internally
            |> Validation.skip_delta_block_chain_validation
                 `This_block_was_not_received_via_gossip
            |> Validation.validate_genesis_protocol_state
                 ~genesis_state_hash:
                   (Protocol_state.genesis_state_hash
                      ~state_hash:(Some previous_protocol_state_hash)
                      previous_protocol_state )
            >>= Validation.validate_frontier_dependencies
                  ~context:(module Context)
                  ~root_block:
                    ( Transition_frontier.root frontier
                    |> Breadcrumb.block_with_hash )
                  ~get_block_by_hash:
                    (Fn.compose
                       (Option.map ~f:Breadcrumb.block_with_hash)
                       (Transition_frontier.find frontier) )
            |> Deferred.return
          in
          let transition_receipt_time = None in
          let%bind breadcrumb =
            time ~logger ~time_controller
              "Build breadcrumb on produced block (precomputed)" (fun () ->
                Breadcrumb.build ~logger ~precomputed_values ~verifier
                  ~get_completed_work:(Fn.const None) ~trust_system
                  ~parent:crumb ~transition ~sender:None
                  ~skip_staged_ledger_verification:`Proofs
                  ~transition_receipt_time ()
                |> Deferred.Result.map_error ~f:(function
                     | `Invalid_staged_ledger_diff e ->
                         `Invalid_staged_ledger_diff (e, staged_ledger_diff)
                     | ( `Fatal_error _
                       | `Invalid_genesis_protocol_state
                       | `Invalid_staged_ledger_hash _
                       | `Not_selected_over_frontier_root
                       | `Parent_missing_from_frontier ) as err ->
                         err ) )
          in
          [%str_log trace]
            ~metadata:[ ("breadcrumb", Breadcrumb.to_yojson breadcrumb) ]
            Block_produced ;
          let metadata =
            [ ( "state_hash"
              , State_hash.to_yojson protocol_state_hashes.state_hash )
            ]
          in
          Mina_metrics.(Counter.inc_one Block_producer.blocks_produced) ;
          Mina_metrics.Block_producer.(
            Block_production_delay_histogram.observe block_production_delay
              Time.(
                Span.to_ms
                @@ diff (now ())
                @@ Block_time.to_time_exn scheduled_time)) ;
          let%bind.Async.Deferred () =
            Strict_pipe.Writer.write transition_writer breadcrumb
          in
          [%log debug] ~metadata
            "Waiting for block $state_hash to be inserted into frontier" ;
          match%bind.Deferred
            wait_for_finalization
              (Time_ns.Span.of_int_sec 20)
              protocol_state_hashes.state_hash
          with
          | `Transition_accepted ->
              [%log info] ~metadata
                "Generated transition $state_hash was accepted into transition \
                 frontier" ;
              return ()
          | `Timed_out ->
              (* FIXME #3167: this should be fatal, and more importantly,
                 shouldn't happen.
              *)
              [%log fatal] ~metadata
                "Timed out waiting for generated transition $state_hash to \
                 enter transition frontier. Continuing to produce new blocks \
                 anyway. This may mean your CPU is overloaded. Consider \
                 disabling `-run-snark-worker` if it's configured." ;
              return ()
        in
        let%bind res = emit_breadcrumb () in
        let span = Block_time.diff (Block_time.now time_controller) start in
        handle_block_production_errors ~logger ~rejected_blocks_logger
          ~time_taken:span ~previous_protocol_state ~protocol_state res
  in
  let rec emit_next_block precomputed_blocks =
    (* Begin checking for the ability to produce a block *)
    match Broadcast_pipe.Reader.peek frontier_reader with
    | None ->
        log_bootstrap_mode () ;
        let%bind () =
          Broadcast_pipe.Reader.iter_until frontier_reader
            ~f:(Fn.compose Deferred.return Option.is_some)
        in
        emit_next_block precomputed_blocks
    | Some _transition_frontier -> (
        match Sequence.next precomputed_blocks with
        | Some (precomputed_block, precomputed_blocks) ->
            let new_time_offset =
              Time.diff (Time.now ())
                (Block_time.to_time_exn
                   precomputed_block.Precomputed.scheduled_time )
            in
            [%log info]
              "Changing time offset from $old_time_offset to $new_time_offset"
              ~metadata:
                [ ( "old_time_offset"
                  , `String
                      (Time.Span.to_string_hum
                         (Block_time.Controller.get_time_offset ~logger) ) )
                ; ( "new_time_offset"
                  , `String (Time.Span.to_string_hum new_time_offset) )
                ] ;
            Block_time.Controller.set_time_offset new_time_offset ;
            let%bind () = produce precomputed_block in
            emit_next_block precomputed_blocks
        | None ->
            return () )
  in
  emit_next_block precomputed_blocks
