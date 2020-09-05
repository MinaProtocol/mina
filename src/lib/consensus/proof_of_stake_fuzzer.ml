[%%import
"../../config.mlh"]

open Core_kernel
open Async
open Unsigned
open Signature_lib
open Coda_base
open Coda_state
open Coda_transition
open Snark_params
open Blockchain_snark
open Consensus
open Data
open Proof_of_stake.Exported

let rec fold_until_none ~init ~f =
  match f init with
  | None ->
      init
  | Some init' ->
      fold_until_none ~init:init' ~f

(* TODO: optimize epoch ledgers? (many duplcate copies right now *)
module Staker = struct
  type t = {keypair: Keypair.And_compressed_pk.t; local_state: Local_state.t}
end

module Vrf_distribution = struct
  open Staker

  type t =
    { start_slot: Global_slot.t
    ; term_slot: Global_slot.t
    ; proposal_table: Block_data.t Public_key.Compressed.Map.t Int.Table.t }

  (** Creates an empty vrf distribution for [~for_epoch]. Note that here,
   *  the ~for_epoch refers to the epoch after the epoch where the vrf
   *  distribution is locked in at the lock checkpoint. This means that,
   *  for all epoch except for the genesis epoch, a vrf distribution for
   *  some epoch [ep] is actually the vrf distribution for [ep-1 + R/3]
   *  to [ep + 2R/3 - 1] (inclusive). In the case of the genesis epoch,
   *  since there is no [ep-1] and the vrf distribution is already
   *  locked, the vrf distribution created is for the range [ep] to
   *  [ep + 2R/3 - 1].
   *)
  let create ~stakers ~epoch ~initial_consensus_state =
    let constants = Constants.compiled in
    Core_kernel.Printf.printf
      !"[%d] Evaluating %d VRFs for %d stakers\n%!"
      (UInt32.to_int epoch)
      (List.length stakers * UInt32.to_int constants.slots_per_epoch)
      (List.length stakers) ;
    let open UInt32 in
    let open UInt32.Infix in
    let open Option.Let_syntax in
    assert (
      Global_slot.epoch @@ Consensus_state.global_slot initial_consensus_state
      = epoch ) ;
    let start_slot =
      if epoch = zero then Global_slot.zero ~constants
      else
        Global_slot.of_epoch_and_slot ~constants
          (epoch - of_int 1, of_int 2 * constants.slots_per_epoch)
    in
    let term_slot =
      Global_slot.of_epoch_and_slot ~constants
        (epoch, (of_int 2 * constants.slots_per_epoch) - of_int 1)
    in
    let start_time = Global_slot.start_time ~constants start_slot in
    let term_time = Global_slot.start_time ~constants term_slot in
    let proposal_table = Int.Table.create () in
    let record_proposal ~staker ~proposal_data =
      let _, pk = staker.keypair in
      let slot = UInt32.to_int @@ Block_data.global_slot proposal_data in
      Hashtbl.update proposal_table slot ~f:(function
        | None ->
            Public_key.Compressed.Map.of_alist_exn [(pk, proposal_data)]
        | Some map ->
            Map.add_exn map ~key:pk ~data:proposal_data )
    in
    List.iter stakers ~f:(fun staker ->
        ignore
        @@ fold_until_none ~init:(initial_consensus_state, start_time)
             ~f:(fun (dummy_consensus_state, curr_time) ->
               let%bind () =
                 Option.some_if Block_time.(curr_time <= term_time) ()
               in
               let%map proposal_time, proposal_data =
                 match
                   Hooks.next_producer_timing ~constants
                     ( Block_time.to_span_since_epoch curr_time
                     |> Block_time.Span.to_ms )
                     dummy_consensus_state ~local_state:staker.local_state
                     ~keypairs:
                       (Keypair.And_compressed_pk.Set.of_list [staker.keypair])
                     ~logger:(Logger.null ())
                 with
                 | `Check_again _ ->
                     None
                 | `Produce_now (_, proposal_data, _) ->
                     let slot_span = constants.block_window_duration_ms in
                     let proposal_time = Block_time.add curr_time slot_span in
                     Some (proposal_time, proposal_data)
                 | `Produce (proposal_time, _, proposal_data, _) ->
                     Some
                       ( Block_time.(
                           of_span_since_epoch @@ Span.of_ms proposal_time)
                       , proposal_data )
               in
               record_proposal ~staker ~proposal_data ;
               let increase_epoch_count =
                 Global_slot.epoch
                   (Consensus_state.global_slot dummy_consensus_state)
                 < Global_slot.(
                     epoch
                       (of_slot_number ~constants
                          (Block_data.global_slot proposal_data)))
               in
               let new_global_slot =
                 Global_slot.of_slot_number ~constants
                   (Block_data.global_slot proposal_data)
               in
               let next_dummy_consensus_state =
                 Consensus_state.Unsafe.dummy_advance dummy_consensus_state
                   ~increase_epoch_count ~new_global_slot
               in
               (next_dummy_consensus_state, proposal_time) ) ) ;
    {start_slot; term_slot; proposal_table}

  (** Picks a single chain of proposals from a distribution. Does not attempt
   *  to simulate any regular properties of how a real chain would be built. *)
  let pick_chain_unrealistically dist =
    let constants = Constants.compiled in
    let default_window_size = UInt32.to_int constants.delta in
    let rec find_potential_proposals acc_proposals window_depth slot =
      let slot_in_dist_range = slot < dist.term_slot in
      let window_expired =
        window_depth >= default_window_size && List.length acc_proposals > 0
      in
      if (not slot_in_dist_range) || window_expired then acc_proposals
      else
        let slot_number = Global_slot.slot_number slot in
        let slot_proposals =
          Hashtbl.find dist.proposal_table (UInt32.to_int slot_number)
          |> Option.map ~f:Map.to_alist |> Option.value ~default:[]
        in
        find_potential_proposals
          (acc_proposals @ slot_proposals)
          (window_depth + 1) (Global_slot.succ slot)
    in
    let rec extend_proposal_chain acc_chain slot =
      let potential_proposals = find_potential_proposals [] 0 slot in
      if List.length potential_proposals = 0 then acc_chain
      else
        let ((_, proposal_data) as proposal) =
          List.random_element_exn potential_proposals
        in
        extend_proposal_chain (proposal :: acc_chain)
          (Global_slot.of_slot_number ~constants
             (UInt32.succ @@ Block_data.global_slot proposal_data))
    in
    extend_proposal_chain [] dist.start_slot |> List.rev

  (*
  let calculate_branch_probability ~from_slot ~to_slot =
    let diff = to_slot - from_slot in
    (* TODO *)
    ()

  let all_possible_chains dist ~base =
    let this_epoch = Consensus_state.epoch base + 1 in
    let start_slot = Global_slot.of_epoch_and_slot this_epoch 0 in
    let term_slot = Global_slot.of_epoch_and_slot (this_epoch + 1) 0 in
    let rec check_slot slot pred =
      if slot >= term_slot then
        []
      else
        let pred_slot = Consensus_state.global_slot pred in
        match
          Option.map (Hashtbl.find dist slot) ~f:Hashtbl.data
        with
        | None -> all_possible_chains (slot + 1) pred
        | Some potential_succ_proposals ->
            List.bind potential_succs_proposals ~f:(fun (succ_proposer, succ_proposal) ->
              if Public_key.equal pred_proposer.keypair.public_key succ_proposer.keypair.public_key then
                compute_branches succ
              else
                let probability = calculate_branch_probability ~from_slot:pred_slot ~to_slot:slot in
                if Float.(Random.float_incl 1.0 >= 1.0 - probablity) then
                  let succ_slot = Consensus_state.global_slot succ in
                  let this_branch = succ :: pred in
                  let future_branches =
                    List.map (check_slot (succ_slot + 1) succ) ~f:(fun branch -> future_branch @ this_branch)
                  in
                  this_branch :: future_branch
                else
                  [])
    in
    check_slot start_slot base
    (* reverse all of the branches since they are computed backwards to reduce list appends *)
    |> List.map ~f:List.rev
  *)
end

(*
(* TODO: determine rules for filtering which chains to traverse.
 * Depending on the strategy, this may need to b implemented when computin the
 * chains instead. *)
let limit_chains_to_traverse chains = chains

let fuzz_vrf_round ~stakers ~base_chains =
  let vrf_dist = Vrf_distribution.compute ~stakers in
  Deferred.List.bind base_chains ~f:(fun base ->
    let all_possible_chains = Vrf_distribution.compute_all_possible_chains vrf_dist ~base in
    let chains_to_traverse = limit_chains_to_traverse all_possible_chains in
    Rose_tree.Deferred.fold_to_leaves_and_save all_possible_chains ~init:base ~f:(fun pred pending_block ->
      let blocks = generate_blocks pending_block in
      let%map () = Deferred.List.iter blocks ~f:check_block in
      blocks))

let run () =
  (* ... *)
  fuzz_vrf_round ~stakers ~base_chains:[genesis_chain]
*)

(* TODO: Should these be runtime configurable? *)

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let precomputed_values = Lazy.force Precomputed_values.compiled

module Genesis_ledger = Genesis_ledger.Make (struct
  include (val Genesis_ledger.fetch_ledger_exn genesis_ledger)

  let directory = `Ephemeral

  let depth = constraint_constants.ledger_depth
end)

let genesis_protocol_state = precomputed_values.protocol_state_with_hash

let create_genesis_data () =
  let genesis_dummy_pk =
    Account.public_key (snd (List.hd_exn (Lazy.force Genesis_ledger.accounts)))
  in
  let empty_diff =
    { Staged_ledger_diff.diff=
        ( { completed_works= []
          ; user_commands= []
          ; coinbase= Staged_ledger_diff.At_most_two.Zero }
        , None )
    ; creator= genesis_dummy_pk
    ; coinbase_receiver= genesis_dummy_pk }
  in
  let genesis_transition =
    External_transition.create
      ~protocol_state:(With_hash.data genesis_protocol_state)
      ~protocol_state_proof:precomputed_values.base_proof
      ~staged_ledger_diff:empty_diff
      ~delta_transition_chain_proof:
        (Protocol_state.previous_state_hash genesis_protocol_state, [])
      ~validation_callback:Fn.ignore ()
  in
  let scan_state = Staged_ledger.Scan_state.empty () in
  let pending_coinbase_collection =
    Pending_coinbase.create () |> Or_error.ok_exn
  in
  let genesis_ledger = Lazy.force Genesis_ledger.t in
  let%map genesis_staged_ledger_res =
    Staged_ledger.of_scan_state_and_ledger_unchecked ~ledger:genesis_ledger
      ~scan_state ~pending_coinbase_collection
      ~snarked_ledger_hash:(Ledger.merkle_root genesis_ledger)
  in
  (genesis_transition, Or_error.ok_exn genesis_staged_ledger_res)

[%%if
proof_level = "full"]

let prove_blockchain ~logger (module Keys : Keys_lib.Keys.S)
    (chain : Blockchain.t) (next_state : Protocol_state.Value.t)
    (block : Snark_transition.value) state_for_handler pending_coinbase =
  let wrap hash proof =
    let module Wrap = Keys.Wrap in
    Tock.prove
      (Tock.Keypair.pk Wrap.keys)
      Wrap.input {Wrap.Prover_state.proof} Wrap.main
      (Wrap_input.of_tick_field hash)
  in
  let next_state_top_hash = Keys.Step.instance_hash next_state in
  let prover_state =
    { Keys.Step.Prover_state.prev_proof= chain.proof
    ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
    ; prev_state= chain.state
    ; expected_next_state= Some next_state
    ; update= block }
  in
  let main x =
    Tick.handle (Keys.Step.main ~logger x)
      (Consensus.Data.Prover_state.handler state_for_handler ~pending_coinbase)
  in
  let res =
    Or_error.try_with (fun () ->
        let prev_proof =
          Tick.prove
            (Tick.Keypair.pk Keys.Step.keys)
            (Keys.Step.input ()) prover_state main next_state_top_hash
        in
        { Blockchain.state= next_state
        ; proof= wrap next_state_top_hash prev_proof } )
  in
  Or_error.iter_error res ~f:(fun e ->
      [%log error]
        ~metadata:[("error", `String (Error.to_string_hum e))]
        "Prover threw an error while extending block: $error" ) ;
  res

[%%elif
proof_level = "check"]

let prove_blockchain ~logger (module Keys : Keys_lib.Keys.S)
    (chain : Blockchain.t) (next_state : Protocol_state.Value.t)
    (block : Snark_transition.value) state_for_handler pending_coinbase =
  let next_state_top_hash = Keys.Step.instance_hash next_state in
  let prover_state =
    { Keys.Step.Prover_state.prev_proof= chain.proof
    ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
    ; prev_state= chain.state
    ; expected_next_state= Some next_state
    ; update= block
    ; genesis_state_hash= With_hash.hash genesis_protocol_state }
  in
  let main x =
    Tick.handle (Keys.Step.main ~logger x)
      (Consensus.Data.Prover_state.handler state_for_handler ~pending_coinbase)
  in
  let res =
    Or_error.map
      (Tick.check
         (main @@ Tick.Field.Var.constant next_state_top_hash)
         prover_state)
      ~f:(fun () ->
        {Blockchain.state= next_state; proof= precomputed_values.genesis_proof}
        )
  in
  Or_error.iter_error res ~f:(fun e ->
      [%log error]
        ~metadata:[("error", `String (Error.to_string_hum e))]
        "Prover threw an error while extending block: $error" ) ;
  res

[%%elif
proof_level = "none"]

let prove_blockchain ~logger:_ _ _ _ _ _ _ =
  failwith "cannot run fuzzer with proof_level = \"none\""

[%%else]

[%%show
proof_level]

[%%error
"invalid proof_level"]

[%%endif]

(* TODO: update stakers' relative local_states *)
let propose_block_onto_chain ~logger ~keys
    (previous_transition, previous_staged_ledger) (proposer_pk, block_data) =
  let consensus_constants = Constants.compiled in
  let open Deferred.Let_syntax in
  let proposal_slot =
    Global_slot.of_slot_number ~constants:consensus_constants
      (Block_data.global_slot block_data)
  in
  let proposal_time =
    Global_slot.start_time ~constants:consensus_constants proposal_slot
  in
  let previous_protocol_state =
    External_transition.protocol_state previous_transition
  in
  let previous_protocol_state_body_hash =
    Protocol_state.body previous_protocol_state |> Protocol_state.Body.hash
  in
  let previous_ledger_hash =
    Protocol_state.blockchain_state previous_protocol_state
    |> Blockchain_state.snarked_ledger_hash
  in
  let previous_protocol_state_proof =
    External_transition.protocol_state_proof previous_transition
  in
  (* TODO: insert random txns into the pool every block *)
  let transactions_by_fee = Sequence.empty in
  (* TODO: return random completed work every block *)
  let get_completed_work _statement = None in
  let staged_ledger_diff =
    Staged_ledger.create_diff previous_staged_ledger ~logger ~self:proposer_pk
      ~transactions_by_fee ~get_completed_work ~coinbase_receiver:`Producer
  in
  let%map ( `Hash_after_applying next_staged_ledger_hash
          , `Ledger_proof ledger_proof_opt
          , `Staged_ledger staged_ledger
          , `Pending_coinbase_update (is_new_stack, pending_coinbase_update) )
      =
    let%map res =
      Staged_ledger.apply_diff_unchecked previous_staged_ledger ~logger
        staged_ledger_diff ~state_body_hash:previous_protocol_state_body_hash
    in
    res
    |> Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
    |> Or_error.ok_exn
  in
  let next_ledger_hash =
    Option.value_map ledger_proof_opt
      ~f:(fun (proof, _) ->
        Ledger_proof.statement proof |> Ledger_proof.statement_target )
      ~default:previous_ledger_hash
  in
  let blockchain_state =
    Blockchain_state.create_value ~timestamp:proposal_time
      ~snarked_ledger_hash:next_ledger_hash
      ~staged_ledger_hash:next_staged_ledger_hash
  in
  let supply_increase =
    Option.value_map ledger_proof_opt
      ~f:(fun (proof, _) -> (Ledger_proof.statement proof).supply_increase)
      ~default:Currency.Amount.zero
  in
  let protocol_state, consensus_transition =
    Consensus_state_hooks.generate_transition ~logger ~previous_protocol_state
      ~blockchain_state
      ~current_time:
        (Block_time.Span.to_ms @@ Block_time.to_span_since_epoch proposal_time)
      ~block_data
      ~transactions:
        ( Staged_ledger_diff.With_valid_signatures_and_proofs.user_commands
            staged_ledger_diff
          :> User_command.t list )
      ~snarked_ledger_hash:previous_ledger_hash ~supply_increase
  in
  let snark_transition =
    Snark_transition.create_value
      ?sok_digest:
        (Option.map ledger_proof_opt ~f:(fun (proof, _) ->
             Ledger_proof.sok_digest proof ))
      ?ledger_proof:
        (Option.map ledger_proof_opt ~f:(fun (proof, _) ->
             Ledger_proof.underlying_proof proof ))
      ~supply_increase:
        (Option.value_map ~default:Currency.Amount.zero
           ~f:(fun (proof, _) -> (Ledger_proof.statement proof).supply_increase)
           ledger_proof_opt)
      ~blockchain_state:(Protocol_state.blockchain_state protocol_state)
      ~consensus_transition ~pending_coinbase_update ()
  in
  let internal_transition =
    Internal_transition.create ~snark_transition
      ~prover_state:(Consensus.Data.Block_data.prover_state block_data)
      ~staged_ledger_diff:(Staged_ledger_diff.forget staged_ledger_diff)
  in
  let pending_coinbase_witness =
    { Pending_coinbase_witness.pending_coinbases=
        Staged_ledger.pending_coinbase_collection previous_staged_ledger
    ; is_new_stack }
  in
  let {Blockchain.proof= protocol_state_proof; _} =
    prove_blockchain ~logger keys
      (Blockchain.create ~proof:previous_protocol_state_proof
         ~state:previous_protocol_state)
      protocol_state
      (Internal_transition.snark_transition internal_transition)
      (Internal_transition.prover_state internal_transition)
      pending_coinbase_witness
    |> Or_error.ok_exn
  in
  let dummy_delta_transition_chain_proof = (State_hash.dummy, []) in
  let external_transition =
    External_transition.create ~protocol_state ~protocol_state_proof
      ~staged_ledger_diff:(Staged_ledger_diff.forget staged_ledger_diff)
      ~delta_transition_chain_proof:dummy_delta_transition_chain_proof
      ~validation_callback:Fn.ignore ()
  in
  (external_transition, staged_ledger)

let main () =
  let logger = Logger.create ~id:"fuzz" () in
  let consensus_constants = Constants.compiled in
  Logger.(
    Consumer_registry.register ~id:"fuzz" ~processor:(Processor.raw ())
      ~transport:
        (Transport.File_system.dumb_logrotate ~directory:"fuzz_logs"
           ~log_filename:"log"
           ~max_size:(500 * 1024 * 1024))) ;
  don't_wait_for
    (let%bind genesis_transition, genesis_staged_ledger =
       create_genesis_data ()
     in
     let%bind keys = Keys_lib.Keys.create () in
     let stakers =
       List.map (Lazy.force Genesis_ledger.accounts)
         ~f:(fun (sk_opt, _account) ->
           let sk = Option.value_exn sk_opt in
           let raw_keypair = Keypair.of_private_key_exn sk in
           let compressed_pk = Public_key.compress raw_keypair.public_key in
           let keypair = (raw_keypair, compressed_pk) in
           let local_state =
             Local_state.create
               (Public_key.Compressed.Set.of_list [compressed_pk])
               ~genesis_ledger:Genesis_ledger.t
           in
           Staker.{keypair; local_state} )
     in
     let rec loop epoch (base_transition, base_staged_ledger) =
       let dist =
         Vrf_distribution.create ~stakers ~epoch
           ~initial_consensus_state:
             (External_transition.consensus_state base_transition)
       in
       let proposal_chain = Vrf_distribution.pick_chain_unrealistically dist in
       Core_kernel.Printf.printf
         !"[%d] proposing chain of length %d\n%!"
         (UInt32.to_int epoch)
         (List.length proposal_chain) ;
       (*
      Core.Printf.printf !"%s\n%!"
        (String.concat ~sep:":" @@ List.map proposal_chain ~f:(fun (_, block_data) ->
          UInt32.to_string @@ Global_slot.slot @@ Block_data.global_slot block_data));
      *)
       let%bind final_chain =
         Deferred.List.fold proposal_chain
           ~init:(base_transition, base_staged_ledger)
           ~f:(fun previous_chain ((_, block_data) as proposal) ->
             Core.Printf.printf !"[%d] %d --> %d\n%!" (UInt32.to_int epoch)
               ( UInt32.to_int @@ Global_slot.slot_number
               @@ Consensus_state.global_slot
               @@ External_transition.consensus_state @@ fst previous_chain )
               ( UInt32.to_int
               @@ Global_slot.(
                    slot
                      (of_slot_number ~constants:consensus_constants
                         (Block_data.global_slot block_data))) ) ;
             propose_block_onto_chain ~logger ~keys previous_chain proposal )
       in
       loop (UInt32.succ epoch) final_chain
     in
     loop UInt32.zero (genesis_transition, genesis_staged_ledger))

let _ = Async.Scheduler.go_main ~main ()
