open Core
open Mina_base
open Mina_state

type t =
  { precomputed_values : Precomputed_values.t
  ; context : (module Consensus.Intf.CONTEXT)
  ; current : Frontier_base.Breadcrumb.t
  ; logger : Logger.t
  ; snarked_root : Mina_ledger.Root.t
  ; root_ledger : Mina_ledger.Ledger.Any_ledger.witness
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  }

let current t = t.current

let precomputed_values t = t.precomputed_values

let context t = t.context

let consensus_local_state t = t.consensus_local_state

let protocol_states t = t.protocol_states

let create ~precomputed_values ~context ~keys_module ~keypair ~logger ~state_dir
    () =
  let open Async in
  let open Deferred.Or_error.Let_syntax in
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
  in
  let root_ledger = Mina_ledger.Root.as_unmasked snarked_root in
  let%map genesis_breadcrumb =
    Genesis.create_genesis_breadcrumb ~logger ~precomputed_values ~root_ledger
      keys_module ()
  in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.Precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location:(Filename.concat state_dir "epoch_ledger")
      (Signature_lib.Public_key.Compressed.Set.singleton
         (Signature_lib.Public_key.compress
            keypair.Signature_lib.Keypair.public_key ) )
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Stable_db
  in
  let hash = Frontier_base.Breadcrumb.state_hash genesis_breadcrumb in
  let protocol_state =
    Frontier_base.Breadcrumb.protocol_state genesis_breadcrumb
  in
  let protocol_states = State_hash.Map.singleton hash protocol_state in
  { precomputed_values
  ; context
  ; current = genesis_breadcrumb
  ; logger
  ; snarked_root
  ; root_ledger
  ; protocol_states
  ; consensus_local_state
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

let add_breadcrumb t raw_breadcrumb =
  let state_hash = Frontier_base.Breadcrumb.state_hash raw_breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state raw_breadcrumb in
  let protocol_states =
    State_hash.Map.set t.protocol_states ~key:state_hash ~data:protocol_state
  in
  let t = { t with protocol_states } in
  let breadcrumb =
    perform_root_transition t ~prev_breadcrumb:t.current
      ~new_breadcrumb:raw_breadcrumb
  in
  (breadcrumb, { t with current = breadcrumb })
