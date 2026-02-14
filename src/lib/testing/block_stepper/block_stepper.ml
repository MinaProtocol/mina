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
  ; proof_cache_db : Proof_cache_tag.cache_db
  ; epoch_data :
      Consensus.Data.Epoch_data_for_vrf.t
      * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  }

let current_block t = Linear_frontier.current t.frontier

let precomputed_values t = Linear_frontier.precomputed_values t.frontier

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
    ~state_dir () =
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
      ~logger ~state_dir ()
  in
  let genesis_breadcrumb = Linear_frontier.current frontier in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.to_int |> ( + ) 1
  in
  let%map proof_cache_db =
    Proof_cache_tag.create_db (Filename.concat state_dir "proof_cache") ~logger
    |> Deferred.Result.map_error ~f:(fun (`Initialization_error e) -> e)
  in
  let consensus_state =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
  in
  let consensus_local_state = Linear_frontier.consensus_local_state frontier in
  let epoch_data =
    get_epoch_data_at_slot ~context ~consensus_state
      ~local_state:consensus_local_state ~slot:next_search_slot
  in
  { frontier
  ; keys_module
  ; keypair
  ; next_search_slot
  ; proof_cache_db
  ; epoch_data
  }

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
  let signature_kind = precomputed_values.signature_kind in
  let protocol_states = Linear_frontier.protocol_states t.frontier in
  let%bind raw_breadcrumb =
    Block_builder.build_breadcrumb ~transactions ~context ~precomputed_values
      ~signature_kind ~proof_cache_db:t.proof_cache_db ~protocol_states
      t.keys_module
      (slot_won, ledger_snapshot)
      current
  in
  let%map breadcrumb, frontier =
    Linear_frontier.add_breadcrumb t.frontier raw_breadcrumb |> Deferred.return
  in
  (breadcrumb, { t with frontier; next_search_slot; epoch_data })
