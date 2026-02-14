open Core
open Async
open Signature_lib
open Mina_base
open Mina_state

module type Keys_S = Block_builder.Keys_S

module Keys = Block_builder.Keys

let create_genesis_breadcrumb = Genesis.create_genesis_breadcrumb

type t =
  { precomputed_values : Precomputed_values.t
  ; context : (module Consensus.Intf.CONTEXT)
  ; keys_module : (module Keys_S)
  ; current : Frontier_base.Breadcrumb.t
  ; logger : Logger.t
  ; keypair : Keypair.t
  ; next_search_slot : int
  ; proof_cache_db : Proof_cache_tag.cache_db
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; epoch_data :
      Consensus.Data.Epoch_data_for_vrf.t
      * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  }

type start_state =
  { breadcrumb : Frontier_base.Breadcrumb.t
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; keys_module : (module Keys_S)
  }

let start_state_of_genesis breadcrumb ~keys_module =
  let hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  { breadcrumb
  ; protocol_states = State_hash.Map.singleton hash protocol_state
  ; keys_module
  }

let start_state_of_breadcrumb breadcrumb ~protocol_states ~keys_module =
  { breadcrumb; protocol_states; keys_module }

let current_block t = t.current

let precomputed_values t = t.precomputed_values

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

let create ~precomputed_values ~keypair ~start ~logger ~state_dir () =
  let start_block = start.breadcrumb in
  let keys_module = start.keys_module in
  let context =
    let module Context = struct
      let logger = logger

      let constraint_constants =
        precomputed_values.Precomputed_values.constraint_constants

      let consensus_constants = precomputed_values.consensus_constants
    end in
    (module Context : Consensus.Intf.CONTEXT)
  in
  let (module Context : Consensus.Intf.CONTEXT) = context in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state start_block
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.to_int |> ( + ) 1
  in
  let%bind proof_cache_db =
    Proof_cache_tag.create_db (Filename.concat state_dir "proof_cache") ~logger
    >>| Result.map_error ~f:(fun (`Initialization_error e) -> e)
    >>| Or_error.ok_exn
  in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.Precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location:(Filename.concat state_dir "epoch_ledger")
      (Public_key.Compressed.Set.singleton
         (Public_key.compress keypair.Keypair.public_key) )
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Stable_db
  in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state start_block in
  let epoch_data =
    get_epoch_data_at_slot
      ~context:(module Context)
      ~consensus_state ~local_state:consensus_local_state ~slot:next_search_slot
  in
  return
    { precomputed_values
    ; context
    ; keys_module
    ; current = start_block
    ; logger
    ; keypair
    ; next_search_slot
    ; proof_cache_db
    ; protocol_states = start.protocol_states
    ; consensus_local_state
    ; epoch_data
    }

let step t ~transactions =
  let logger = t.logger in
  let (module Context : Consensus.Intf.CONTEXT) = t.context in
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let max_search_slots = 2 * slots_per_epoch in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state t.current in
  let rec find_slot ~epoch_data ~start_slot ~slots_searched =
    if slots_searched >= max_search_slots then
      failwith "Could not find winning slot within 2 epochs" ;
    let epoch_data_for_vrf, ledger_snapshot = epoch_data in
    let epoch_end_slot =
      ((start_slot / slots_per_epoch) + 1) * slots_per_epoch
    in
    match%bind
      Vrf.find_next_winning_slot ~context:t.context ~keypair:t.keypair
        ~start_slot ~epoch_data_for_vrf ~ledger_snapshot
    with
    | Some (winner, next_slot) ->
        return (winner, next_slot, epoch_data)
    | None ->
        [%log info] "Epoch exhausted at slot %d, recomputing for next epoch"
          epoch_end_slot ;
        let new_epoch_data =
          get_epoch_data_at_slot ~context:t.context ~consensus_state
            ~local_state:t.consensus_local_state ~slot:epoch_end_slot
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
  let signature_kind = t.precomputed_values.signature_kind in
  let%map breadcrumb =
    Block_builder.build_breadcrumb ~transactions ~context:t.context
      ~precomputed_values:t.precomputed_values ~signature_kind
      ~proof_cache_db:t.proof_cache_db ~protocol_states:t.protocol_states
      t.keys_module
      (slot_won, ledger_snapshot)
      t.current
  in
  let state_hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  let protocol_states =
    State_hash.Map.set t.protocol_states ~key:state_hash ~data:protocol_state
  in
  ( breadcrumb
  , { t with
      current = breadcrumb
    ; next_search_slot
    ; protocol_states
    ; epoch_data
    } )
