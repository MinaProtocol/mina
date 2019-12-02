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
      -> State_hash.var * Protocol_state.var
      -> Snark_transition.var
      -> ( State_hash.var
           * Protocol_state.var
           * [`Success of Boolean.var]
           * [`Is_first_block of Boolean.var]
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
    let verify_complete_merge =
      match Coda_compile_config.proof_level with
      | "full" ->
          T.verify_complete_merge
      | _ ->
          fun _ _ _ _ _ _ _ -> Checked.return Boolean.true_

    let%snarkydef update ~(logger : Logger.t)
        ((previous_state_hash, previous_state) :
          State_hash.var * Protocol_state.var)
        (transition : Snark_transition.var) :
        ( State_hash.var
          * Protocol_state.var
          * [`Success of Boolean.var]
          * [`Is_first_block of Boolean.var]
        , _ )
        Tick.Checked.t =
      let supply_increase = Snark_transition.supply_increase transition in
      let%bind `Success updated_consensus_state, consensus_state =
        with_label __LOC__
          (Consensus_state_hooks.next_state_checked ~prev_state:previous_state
             ~prev_state_hash:previous_state_hash transition supply_increase)
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
        let%bind nothing_changed =
          Boolean.(ledger_hash_didn't_change && supply_increase_is_zero)
        in
        let%bind new_pending_coinbase_hash, deleted_stack =
          let%bind root_after_delete, deleted_stack =
            Pending_coinbase.Checked.pop_coinbases prev_pending_coinbase_root
              ~proof_emitted:(Boolean.not ledger_hash_didn't_change)
          in
          (*new stack or update one*)
          let%map new_root =
            Pending_coinbase.Checked.add_coinbase root_after_delete
              ( Snark_transition.proposer transition
              , Snark_transition.coinbase_amount transition
              , Snark_transition.coinbase_state_body_hash transition )
          in
          if Coda_compile_config.pending_coinbase_hack then
            (new_root, Pending_coinbase.Stack.Checked.empty)
          else (new_root, deleted_stack)
        in
        let%bind correct_coinbase_status =
          let new_root =
            transition |> Snark_transition.blockchain_state
            |> Blockchain_state.staged_ledger_hash
            |> Staged_ledger_hash.pending_coinbase_hash_var
          in
          (*TODO: disabling the pending coinbase check until the prover crash is fixed*)
          if Coda_compile_config.pending_coinbase_hack then
            Checked.return Boolean.true_
          else
            Pending_coinbase.Hash.equal_var new_pending_coinbase_hash new_root
        in
        let%bind correct_transaction_snark =
          with_label __LOC__
            (verify_complete_merge
               (Snark_transition.sok_digest transition)
               ( previous_state |> Protocol_state.blockchain_state
               |> Blockchain_state.snarked_ledger_hash )
               ( transition |> Snark_transition.blockchain_state
               |> Blockchain_state.snarked_ledger_hash )
               Pending_coinbase.Stack.Checked.empty deleted_stack
               supply_increase
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
                and updated_consensus_state =
                  read Boolean.typ updated_consensus_state
                and correct_coinbase_status =
                  read Boolean.typ correct_coinbase_status
                and result = read Boolean.typ result in
                Logger.trace logger
                  "blockchain snark update success (check pending coinbase = \
                   $check): $result = \
                   (correct_transaction_snark=$correct_transaction_snark ∨ \
                   nothing_changed=$nothing_changed) ∧ \
                   updated_consensus_state=$updated_consensus_state ∧ \
                   correct_coinbase_status=$correct_coinbase_status"
                  ~module_:__MODULE__ ~location:__LOC__
                  ~metadata:
                    [ ( "correct_transaction_snark"
                      , `Bool correct_transaction_snark )
                    ; ("nothing_changed", `Bool nothing_changed)
                    ; ("updated_consensus_state", `Bool updated_consensus_state)
                    ; ("correct_coinbase_status", `Bool correct_coinbase_status)
                    ; ("result", `Bool result)
                    ; ("check", `Bool Coda_compile_config.pending_coinbase_hack)
                    ]))
        in
        result
      in
      let%bind is_first_block =
        previous_state |> Protocol_state.consensus_state
        |> Consensus.Data.Consensus_state.is_genesis_state_var
      in
      let%bind genesis_state_hash =
        State_hash.if_ is_first_block
          ~then_:(Snark_transition.genesis_protocol_state_hash transition)
          ~else_:(Protocol_state.genesis_state_hash previous_state)
      in
      let new_state =
        Protocol_state.create_var ~previous_state_hash ~genesis_state_hash
          ~blockchain_state:(Snark_transition.blockchain_state transition)
          ~consensus_state
      in
      let%bind () =
        as_prover
          As_prover.(
            Let_syntax.(
              let%map protocol_state = read Protocol_state.typ new_state in
              Core.printf
                !"Genesis state: %{sexp: Coda_state.Protocol_state.value}\n%!"
                protocol_state))
      in
      let%map state_hash = Protocol_state.hash_checked new_state in
      (state_hash, new_state, `Success success, `Is_first_block is_first_block)
  end
end

module Checked = struct
  let%snarkydef is_base_hash h =
    Field.Checked.equal
      (Field.Var.constant
         ( (Lazy.force Genesis_protocol_state.compile_time_genesis).hash
           :> Field.t ))
      (State_hash.var_to_hash_packed h)

  let%snarkydef hash (t : Protocol_state.var) = Protocol_state.hash_checked t
end
