(* TODO: rename *)

open Core_kernel
open Snark_params
open Tick
open Coda_base
open Coda_state

module type Update_intf = sig
  module Checked : sig
    val update :
         logger:Logger.t
      -> proof_level:Genesis_constants.Proof_level.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> State_hash.var * State_body_hash.var * Protocol_state.var
      -> Snark_transition.var
      -> ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
         , _ )
         Checked.t
  end
end

module Make_update (T : Transaction_snark.Verification.S) = struct
  module Checked = struct
    (* Blockchain_snark ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
          Input:
            old : Blockchain.t
            old_snark : proof
            nonce : int
            work_snark : proof
            ledger_hash : Ledger_hash.t
            timestamp : Time.t
            new_hash : State_hash.t
          Witness:
            transition : Transition.t
          such that
            the old_snark verifies against old
            new = update_with_asserts(old, nonce, timestamp, ledger_hash)
            hash(new) = new_hash
            the work_snark verifies against the old.ledger_hash and new_ledger_hash
            new.timestamp > old.timestamp
            transition consensus data is valid
            new consensus state is a function of the old consensus state
    *)
    let verify_complete_merge ~proof_level =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          T.verify_complete_merge
      | _ ->
          fun _ _ _ _ _ _ _ _ _ -> Checked.return Boolean.true_

    let%snarkydef update ~(logger : Logger.t) ~proof_level
        ~constraint_constants
        ((previous_state_hash, previous_state_body_hash, previous_state) :
          State_hash.var * State_body_hash.var * Protocol_state.var)
        (transition : Snark_transition.var) :
        ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
        , _ )
        Tick.Checked.t =
      let supply_increase = Snark_transition.supply_increase transition in
      let%bind `Success updated_consensus_state, consensus_state =
        with_label __LOC__
          (Consensus_state_hooks.next_state_checked ~constraint_constants
             ~prev_state:previous_state ~prev_state_hash:previous_state_hash
             transition supply_increase)
      in
      let prev_pending_coinbase_root =
        previous_state |> Protocol_state.blockchain_state
        |> Blockchain_state.staged_ledger_hash
        |> Staged_ledger_hash.pending_coinbase_hash_var
      in
      let%bind success =
        let%bind ledger_hash_didn't_change =
          Frozen_ledger_hash.equal_var
            ( previous_state |> Protocol_state.blockchain_state
            |> Blockchain_state.snarked_ledger_hash )
            ( transition |> Snark_transition.blockchain_state
            |> Blockchain_state.snarked_ledger_hash )
        and supply_increase_is_zero =
          Currency.Amount.(equal_var supply_increase (var_of_t zero))
        in
        let%bind new_pending_coinbase_hash, deleted_stack, no_coinbases_popped
            =
          let%bind root_after_delete, deleted_stack =
            Pending_coinbase.Checked.pop_coinbases ~constraint_constants
              prev_pending_coinbase_root
              ~proof_emitted:(Boolean.not ledger_hash_didn't_change)
          in
          (*If snarked ledger hash did not change (no new ledger proof) then pop_coinbases should be a no-op*)
          let%bind no_coinbases_popped =
            Pending_coinbase.Hash.equal_var root_after_delete
              prev_pending_coinbase_root
          in
          (*new stack or update one*)
          let%map new_root =
            with_label __LOC__
              (Pending_coinbase.Checked.add_coinbase ~constraint_constants
                 root_after_delete
                 ( Snark_transition.pending_coinbase_action transition
                 , ( Snark_transition.coinbase_receiver transition
                   , Snark_transition.coinbase_amount transition )
                 , previous_state_body_hash ))
          in
          (new_root, deleted_stack, no_coinbases_popped)
        in
        let%bind nothing_changed =
          Boolean.all
            [ ledger_hash_didn't_change
            ; supply_increase_is_zero
            ; no_coinbases_popped ]
        in
        let%bind correct_coinbase_status =
          let new_root =
            transition |> Snark_transition.blockchain_state
            |> Blockchain_state.staged_ledger_hash
            |> Staged_ledger_hash.pending_coinbase_hash_var
          in
          Pending_coinbase.Hash.equal_var new_pending_coinbase_hash new_root
        in
        let pending_coinbase_source_stack =
          Pending_coinbase.Stack.Checked.create_with deleted_stack
        in
        let%bind correct_transaction_snark =
          with_label __LOC__
            (verify_complete_merge ~proof_level
               (Snark_transition.sok_digest transition)
               ( previous_state |> Protocol_state.blockchain_state
               |> Blockchain_state.snarked_ledger_hash )
               ( transition |> Snark_transition.blockchain_state
               |> Blockchain_state.snarked_ledger_hash )
               pending_coinbase_source_stack deleted_stack supply_increase
               ( previous_state |> Protocol_state.blockchain_state
               |> Blockchain_state.snarked_next_available_token )
               ( transition |> Snark_transition.blockchain_state
               |> Blockchain_state.snarked_next_available_token )
               (As_prover.return
                  (Option.value ~default:Tock.Proof.dummy
                     (Snark_transition.ledger_proof transition))))
        in
        let%bind correct_snark =
          Boolean.(correct_transaction_snark || nothing_changed)
        in
        let%bind result =
          Boolean.all
            [correct_snark; updated_consensus_state; correct_coinbase_status]
        in
        let%map () =
          as_prover
            As_prover.(
              Let_syntax.(
                let%map correct_transaction_snark =
                  read Boolean.typ correct_transaction_snark
                and nothing_changed = read Boolean.typ nothing_changed
                and no_coinbases_popped = read Boolean.typ no_coinbases_popped
                and updated_consensus_state =
                  read Boolean.typ updated_consensus_state
                and correct_coinbase_status =
                  read Boolean.typ correct_coinbase_status
                and result = read Boolean.typ result in
                Logger.trace logger
                  "blockchain snark update success: $result = \
                   (correct_transaction_snark=$correct_transaction_snark ∨ \
                   nothing_changed \
                   (no_coinbases_popped=$no_coinbases_popped)=$nothing_changed) \
                   ∧ updated_consensus_state=$updated_consensus_state ∧ \
                   correct_coinbase_status=$correct_coinbase_status"
                  ~module_:__MODULE__ ~location:__LOC__
                  ~metadata:
                    [ ( "correct_transaction_snark"
                      , `Bool correct_transaction_snark )
                    ; ("nothing_changed", `Bool nothing_changed)
                    ; ("updated_consensus_state", `Bool updated_consensus_state)
                    ; ("correct_coinbase_status", `Bool correct_coinbase_status)
                    ; ("result", `Bool result)
                    ; ("no_coinbases_popped", `Bool no_coinbases_popped) ]))
        in
        result
      in
      let%bind genesis_state_hash =
        (*get the genesis state hash from previous state unless previous state is the genesis state itslef*)
        Protocol_state.genesis_state_hash_checked
          ~state_hash:previous_state_hash previous_state
      in
      let new_state =
        Protocol_state.create_var ~previous_state_hash ~genesis_state_hash
          ~blockchain_state:(Snark_transition.blockchain_state transition)
          ~consensus_state
          ~constants:(Protocol_state.constants previous_state)
      in
      let%map state_hash, _ = Protocol_state.hash_checked new_state in
      (state_hash, new_state, `Success success)
  end
end

module Checked = struct
  let%snarkydef is_base_case state =
    Protocol_state.consensus_state state
    |> Consensus.Data.Consensus_state.is_genesis_state_var

  let%snarkydef hash (t : Protocol_state.var) = Protocol_state.hash_checked t
end
