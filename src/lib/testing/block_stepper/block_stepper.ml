open Core
open Async
open Signature_lib

module type Keys_S = Block_builder.Keys_S

module Keys = Block_builder.Keys

type t =
  { frontier : Linear_frontier.t
  ; keys_module : (module Keys_S)
  ; keypair : Keypair.t
  ; next_search_slot : int
  ; snark_work_provider : Snark_work.provider
  ; epoch_data :
      Consensus.Data.Epoch_data_for_vrf.t
      * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  ; precomputed_blocks_path : string option
  }

let current_block t = Linear_frontier.current t.frontier

let precomputed_values t = Linear_frontier.precomputed_values t.frontier

let precomputed_blocks_path t = t.precomputed_blocks_path

let maybe_log_precomputed_block t ~logger ~constraint_constants ~scheduled_time
    raw_breadcrumb =
  Option.iter t.precomputed_blocks_path ~f:(fun path ->
      let precomputed =
        Mina_block.Precomputed.of_block ~logger ~constraint_constants
          ~scheduled_time
          ~staged_ledger:(Frontier_base.Breadcrumb.staged_ledger raw_breadcrumb)
          ~accounts_created:
            (Frontier_base.Breadcrumb.accounts_created raw_breadcrumb)
          (Frontier_base.Breadcrumb.block_with_hash raw_breadcrumb)
      in
      let json =
        Yojson.Safe.to_string (Mina_block.Precomputed.to_yojson precomputed)
      in
      Out_channel.with_file ~append:true path ~f:(fun oc ->
          Out_channel.output_lines oc [ json ] ) )

let get_epoch_data_at_slot ~context:(module Context : Consensus.Intf.CONTEXT)
    ~consensus_state ~local_state ~slot =
  let global_slot = Mina_numbers.Global_slot_since_hard_fork.of_int slot in
  let time =
    Consensus.Data.Consensus_time.(
      start_time ~constants:Context.consensus_constants
        (of_global_slot ~constants:Context.consensus_constants global_slot))
  in
  let now = Block_time.Span.to_ms (Block_time.to_span_since_epoch time) in
  Consensus.Hooks.get_epoch_data_for_vrf ~constants:Context.consensus_constants
    now consensus_state ~local_state ~logger:Context.logger

let create_from_genesis ~precomputed_values ~keypair ~keys_module ~logger
    ~state_dir ?parallel_workers ?(genesis_mode = `Full)
    ?(log_precomputed_blocks = false) () =
  let open Deferred.Or_error.Let_syntax in
  let context =
    let module Context = struct
      let logger = logger

      let constraint_constants =
        precomputed_values.Precomputed_values.constraint_constants

      let consensus_constants = precomputed_values.consensus_constants
    end in
    (module Context : Consensus.Intf.CONTEXT)
  in
  let%bind frontier =
    Linear_frontier.create ~precomputed_values ~context ~keys_module ~keypair
      ~logger ~state_dir ~genesis_mode ()
  in
  let genesis_breadcrumb = Linear_frontier.current frontier in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.to_int |> ( + ) 1
  in
  let%bind proof_cache_db =
    Proof_cache_tag.create_db (Filename.concat state_dir "proof_cache") ~logger
    |> Deferred.Result.map_error ~f:(fun (`Initialization_error e) -> e)
  in
  let (module Keys : Keys_S) = keys_module in
  let proof_level = precomputed_values.Precomputed_values.proof_level in
  let signature_kind = precomputed_values.signature_kind in
  let%map snark_work_provider =
    match parallel_workers with
    | Some n when n > 0 ->
        Snark_work.create_parallel ~num_workers:n ~proof_level ~proof_cache_db
          ~signature_kind
          ~constraint_constants:precomputed_values.constraint_constants ~logger
        |> Deferred.map ~f:Or_error.return
    | _ ->
        Deferred.Or_error.return
          (Snark_work.create_direct ~proof_level ~proof_cache_db ~signature_kind
             ~logger
             (module Keys.T) )
  in
  let consensus_state =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
  in
  let consensus_local_state = Linear_frontier.consensus_local_state frontier in
  let epoch_data =
    get_epoch_data_at_slot ~context ~consensus_state
      ~local_state:consensus_local_state ~slot:next_search_slot
  in
  let precomputed_blocks_path =
    if log_precomputed_blocks then
      Some (Filename.concat state_dir "precomputed_blocks.jsonl")
    else None
  in
  { frontier
  ; keys_module
  ; keypair
  ; next_search_slot
  ; snark_work_provider
  ; epoch_data
  ; precomputed_blocks_path
  }

let step_at_slot t ~global_slot_since_genesis ~block_stake_winner ~transactions
    ?snark_work_count ?scheduled_time =
  let open Deferred.Or_error.Let_syntax in
  let context = Linear_frontier.context t.frontier in
  let (module Context : Consensus.Intf.CONTEXT) = context in
  let logger = Context.logger in
  let current = Linear_frontier.current t.frontier in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state current in
  let consensus_local_state =
    Linear_frontier.consensus_local_state t.frontier
  in
  (* For non-hard-fork networks (fresh genesis), global_slot_since_genesis
     equals global_slot_since_hard_fork numerically. *)
  let slot_int =
    Mina_numbers.Global_slot_since_genesis.to_int global_slot_since_genesis
  in
  let global_slot = Mina_numbers.Global_slot_since_hard_fork.of_int slot_int in
  (* Get epoch data for the target slot *)
  let epoch_data_for_vrf, ledger_snapshot =
    get_epoch_data_at_slot ~context ~consensus_state
      ~local_state:consensus_local_state ~slot:slot_int
  in
  let { Consensus.Data.Epoch_data_for_vrf.epoch_seed
      ; delegatee_table
      ; epoch_ledger
      ; global_slot = epoch_start_hf
      ; global_slot_since_genesis = epoch_start
      ; epoch = _
      } =
    epoch_data_for_vrf
  in
  let public_key_compressed =
    Public_key.compress t.keypair.Keypair.public_key
  in
  (* Run VRF check at the specific slot *)
  let%bind `Vrf_eval _vrf_eval, `Vrf_output vrf_result, `Delegator delegator =
    Consensus.Data.Vrf.check
      ~context:(module Context)
      ~global_slot ~seed:epoch_seed
      ~get_delegators:(Public_key.Compressed.Table.find delegatee_table)
      ~producer_private_key:t.keypair.private_key
      ~producer_public_key:public_key_compressed
      ~total_stake:epoch_ledger.total_currency
    |> Interruptible.force
    |> Deferred.map ~f:(function
         | Error () ->
             Or_error.error_string "VRF check failed"
         | Ok None ->
             Or_error.errorf "VRF did not win at slot %d" slot_int
         | Ok (Some result) ->
             Ok result )
  in
  (* Verify the delegator matches the expected block_stake_winner *)
  let winner_pk = fst delegator in
  let%bind () =
    if Public_key.Compressed.equal winner_pk block_stake_winner then
      Deferred.Or_error.ok_unit
    else
      Deferred.Or_error.errorf
        "VRF delegator mismatch at slot %d: expected %s, got %s" slot_int
        (Public_key.Compressed.to_base58_check block_stake_winner)
        (Public_key.Compressed.to_base58_check winner_pk)
  in
  [%log info] "VRF verified at slot %d, building block" slot_int ;
  let slot_won =
    { Consensus.Data.Slot_won.delegator
    ; producer = t.keypair
    ; global_slot
    ; global_slot_since_genesis =
        Mina_numbers.Global_slot_since_genesis.add epoch_start
          ( Mina_numbers.Global_slot_since_hard_fork.diff global_slot
              epoch_start_hf
          |> Option.value_exn ~message:"failed to diff global slots" )
    ; vrf_result
    }
  in
  let precomputed_values = Linear_frontier.precomputed_values t.frontier in
  let protocol_states = Linear_frontier.protocol_states t.frontier in
  let%bind raw_breadcrumb, scheduled_time, invalid_commands =
    Block_builder.build_breadcrumb ~transactions ~context ~precomputed_values
      ~snark_work_provider:t.snark_work_provider ~protocol_states
      ?snark_work_count ?scheduled_time t.keys_module
      (slot_won, ledger_snapshot)
      current
  in
  maybe_log_precomputed_block t ~logger
    ~constraint_constants:precomputed_values.constraint_constants
    ~scheduled_time raw_breadcrumb ;
  let breadcrumb, frontier =
    Linear_frontier.add_breadcrumb t.frontier raw_breadcrumb
  in
  let next_search_slot = slot_int + 1 in
  let epoch_data = (epoch_data_for_vrf, ledger_snapshot) in
  Deferred.Or_error.return
    ( breadcrumb
    , { t with frontier; next_search_slot; epoch_data }
    , invalid_commands )

let step t ~transactions =
  let open Deferred.Or_error.Let_syntax in
  let context = Linear_frontier.context t.frontier in
  let (module Context : Consensus.Intf.CONTEXT) = context in
  let logger = Context.logger in
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let max_search_slots = 2 * slots_per_epoch in
  let current = Linear_frontier.current t.frontier in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state current in
  let consensus_local_state =
    Linear_frontier.consensus_local_state t.frontier
  in
  let rec find_slot ~epoch_data ~start_slot ~slots_searched =
    if slots_searched >= max_search_slots then
      Deferred.Or_error.error_string
        "Could not find winning slot within 2 epochs"
    else
      let epoch_data_for_vrf, ledger_snapshot = epoch_data in
      let epoch_end_slot =
        ((start_slot / slots_per_epoch) + 1) * slots_per_epoch
      in
      let open Async.Deferred.Let_syntax in
      match%bind
        Vrf.find_next_winning_slot ~context ~keypair:t.keypair ~start_slot
          ~epoch_data_for_vrf ~ledger_snapshot
      with
      | Some (winner, next_slot) ->
          Deferred.Or_error.return (winner, next_slot, epoch_data)
      | None ->
          [%log info] "Epoch exhausted at slot %d, recomputing for next epoch"
            epoch_end_slot ;
          let new_epoch_data =
            get_epoch_data_at_slot ~context ~consensus_state
              ~local_state:consensus_local_state ~slot:epoch_end_slot
          in
          let slots_in_this_epoch = epoch_end_slot - start_slot in
          find_slot ~epoch_data:new_epoch_data ~start_slot:epoch_end_slot
            ~slots_searched:(slots_searched + slots_in_this_epoch)
  in
  [%log info] "Searching for next winning slot from slot %d" t.next_search_slot ;
  let%bind (slot_won, ledger_snapshot), next_search_slot, epoch_data =
    find_slot ~epoch_data:t.epoch_data ~start_slot:t.next_search_slot
      ~slots_searched:0
  in
  let precomputed_values = Linear_frontier.precomputed_values t.frontier in
  let protocol_states = Linear_frontier.protocol_states t.frontier in
  let%bind raw_breadcrumb, scheduled_time, invalid_commands =
    Block_builder.build_breadcrumb ~transactions ~context ~precomputed_values
      ~snark_work_provider:t.snark_work_provider ~protocol_states t.keys_module
      (slot_won, ledger_snapshot)
      current
  in
  maybe_log_precomputed_block t ~logger
    ~constraint_constants:precomputed_values.constraint_constants
    ~scheduled_time raw_breadcrumb ;
  let breadcrumb, frontier =
    Linear_frontier.add_breadcrumb t.frontier raw_breadcrumb
  in
  Deferred.Or_error.return
    ( breadcrumb
    , { t with frontier; next_search_slot; epoch_data }
    , invalid_commands )
