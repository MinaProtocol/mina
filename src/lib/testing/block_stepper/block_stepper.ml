open Core
open Async
open Signature_lib
open Mina_base
open Mina_state

module type Keys_S = Block_builder.Keys_S

module Keys = Block_builder.Keys

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
  ; snarked_root : Mina_ledger.Root.t
  ; root_ledger : Mina_ledger.Ledger.Any_ledger.witness
  ; epoch_data :
      Consensus.Data.Epoch_data_for_vrf.t
      * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  }

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

let create_from_genesis ~precomputed_values ~keypair ~keys_module ~logger
    ~state_dir () =
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
  let constraint_constants = Context.constraint_constants in
  let depth = constraint_constants.ledger_depth in
  let snarked_root_config =
    Mina_ledger.Root.Config.with_directory ~backing_type:Stable_db
      ~directory_name:(Filename.concat state_dir "snarked_root")
  in
  let%bind snarked_root =
    Precomputed_values.create_root precomputed_values
      ~config:snarked_root_config ~depth ()
    >>| Or_error.ok_exn
  in
  let root_ledger = Mina_ledger.Root.as_unmasked snarked_root in
  let%bind genesis_breadcrumb =
    Genesis.create_genesis_breadcrumb ~logger ~precomputed_values ~root_ledger
      keys_module ()
  in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
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
  let consensus_state =
    Frontier_base.Breadcrumb.consensus_state genesis_breadcrumb
  in
  let epoch_data =
    get_epoch_data_at_slot
      ~context:(module Context)
      ~consensus_state ~local_state:consensus_local_state ~slot:next_search_slot
  in
  let hash = Frontier_base.Breadcrumb.state_hash genesis_breadcrumb in
  let protocol_state =
    Frontier_base.Breadcrumb.protocol_state genesis_breadcrumb
  in
  let protocol_states = State_hash.Map.singleton hash protocol_state in
  return
    { precomputed_values
    ; context
    ; keys_module
    ; current = genesis_breadcrumb
    ; logger
    ; keypair
    ; next_search_slot
    ; proof_cache_db
    ; protocol_states
    ; consensus_local_state
    ; snarked_root
    ; root_ledger
    ; epoch_data
    }

(* Mirrors full_frontier.ml:move_root but simplified for the linear
   no-branches case. Every new breadcrumb immediately becomes the root. *)
let perform_root_transition t ~prev_breadcrumb ~new_breadcrumb =
  let (module Context : Consensus.Intf.CONTEXT) = t.context in
  let prev_cs = Frontier_base.Breadcrumb.consensus_state prev_breadcrumb in
  let next_cs = Frontier_base.Breadcrumb.consensus_state new_breadcrumb in
  let genesis_ledger_hash =
    prev_breadcrumb |> Frontier_base.Breadcrumb.protocol_state
    |> Protocol_state.blockchain_state |> Blockchain_state.genesis_ledger_hash
  in
  (* STEP 0: notify consensus of root transition for epoch ledger rotation *)
  Consensus.Hooks.frontier_root_transition prev_cs next_cs
    ~local_state:t.consensus_local_state ~snarked_ledger:t.snarked_root
    ~genesis_ledger_hash ;
  let m0 = Frontier_base.Breadcrumb.mask prev_breadcrumb in
  let m1 = Frontier_base.Breadcrumb.mask new_breadcrumb in
  (* STEP 2: commit m1 into m0 *)
  Mina_ledger.Ledger.commit m1 ;
  (* STEP 3: replace staged ledger's mask and reparent *)
  let new_staged_ledger =
    Staged_ledger.replace_ledger_exn
      (Frontier_base.Breadcrumb.staged_ledger new_breadcrumb)
      m0
  in
  Mina_ledger.Ledger.remove_and_reparent_exn m1 m1 ;
  (* STEPS 4-7: update snarked ledger if a proof was emitted *)
  if Frontier_base.Breadcrumb.just_emitted_a_proof new_breadcrumb then (
    let s = t.root_ledger in
    (* STEP 4: create temp mask on snarked ledger *)
    let mt =
      Mina_ledger.Ledger.Maskable.register_mask s
        (Mina_ledger.Ledger.Mask.create
           ~depth:(Mina_ledger.Ledger.Any_ledger.M.depth s)
           () )
    in
    let signature_kind = Mina_signature_kind.t_DEPRECATED in
    (* STEP 5: apply transactions to bring snarked ledger up to date *)
    let apply_first_pass =
      Mina_ledger.Ledger.apply_transaction_first_pass ~signature_kind
        ~constraint_constants:Context.constraint_constants
    in
    let apply_second_pass = Mina_ledger.Ledger.apply_transaction_second_pass in
    let apply_first_pass_sparse_ledger ~global_slot ~txn_state_view
        sparse_ledger txn =
      let open Or_error.Let_syntax in
      let%map _ledger, partial_txn =
        Mina_ledger.Sparse_ledger.apply_transaction_first_pass
          ~constraint_constants:Context.constraint_constants ~txn_state_view
          ~global_slot sparse_ledger txn
      in
      partial_txn
    in
    let get_protocol_state state_hash =
      match State_hash.Map.find t.protocol_states state_hash with
      | Some s ->
          Ok s
      | None ->
          Or_error.errorf "Failed to find protocol state for hash %s"
            (State_hash.to_base58_check state_hash)
    in
    Or_error.ok_exn
      (Staged_ledger.Scan_state.get_snarked_ledger_sync ~ledger:mt
         ~get_protocol_state ~apply_first_pass ~apply_second_pass
         ~apply_first_pass_sparse_ledger ~signature_kind
         (Staged_ledger.scan_state new_staged_ledger) ) ;
    (* Verify the new snarked ledger hash matches what's expected *)
    let new_snarked_ledger_hash = Mina_ledger.Ledger.merkle_root mt in
    let expected_snarked_ledger_hash =
      Frontier_base.Breadcrumb.protocol_state new_breadcrumb
      |> Protocol_state.blockchain_state |> Blockchain_state.snarked_ledger_hash
    in
    assert (
      Ledger_hash.equal new_snarked_ledger_hash expected_snarked_ledger_hash ) ;
    (* STEP 6: commit temp mask into snarked ledger *)
    Mina_ledger.Ledger.commit mt ;
    (* STEP 7: unregister temp mask *)
    ignore
      ( Mina_ledger.Ledger.Maskable.unregister_mask_exn ~loc:__LOC__ mt
        : Mina_ledger.Ledger.unattached_mask ) ) ;
  (* Recreate the breadcrumb with the reparented staged ledger *)
  Frontier_base.Breadcrumb.create
    ~validated_transition:
      (Frontier_base.Breadcrumb.validated_transition new_breadcrumb)
    ~staged_ledger:new_staged_ledger
    ~just_emitted_a_proof:
      (Frontier_base.Breadcrumb.just_emitted_a_proof new_breadcrumb)
    ~transition_receipt_time:
      (Frontier_base.Breadcrumb.transition_receipt_time new_breadcrumb)
    ~accounts_created:[]

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
  let%map raw_breadcrumb =
    Block_builder.build_breadcrumb ~transactions ~context:t.context
      ~precomputed_values:t.precomputed_values ~signature_kind
      ~proof_cache_db:t.proof_cache_db ~protocol_states:t.protocol_states
      t.keys_module
      (slot_won, ledger_snapshot)
      t.current
  in
  let state_hash = Frontier_base.Breadcrumb.state_hash raw_breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state raw_breadcrumb in
  let protocol_states =
    State_hash.Map.set t.protocol_states ~key:state_hash ~data:protocol_state
  in
  let t_with_states = { t with protocol_states } in
  let breadcrumb =
    perform_root_transition t_with_states ~prev_breadcrumb:t.current
      ~new_breadcrumb:raw_breadcrumb
  in
  ( breadcrumb
  , { t_with_states with current = breadcrumb; next_search_slot; epoch_data } )
