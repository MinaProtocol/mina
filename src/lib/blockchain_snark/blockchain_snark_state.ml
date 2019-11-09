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
        ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
        , _ )
        Tick.Checked.t =
      let supply_increase = Snark_transition.supply_increase transition in
      let%bind `Success updated_consensus_state, consensus_state =
        Consensus_state_hooks.next_state_checked ~prev_state:previous_state
          ~prev_state_hash:previous_state_hash transition supply_increase
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
          let%bind prev_state_body_hash =
            Protocol_state.(Body.hash_checked (body previous_state))
          in
          let prev_of_prev_state_hash =
            Protocol_state.previous_state_hash previous_state
          in
          let%bind same =
            State_body_hash.equal_var prev_state_body_hash
              (Snark_transition.coinbase_state_body_hash transition)
          in
          let%bind empty_hash =
            State_body_hash.equal_var
              (Snark_transition.coinbase_state_body_hash transition)
              (State_body_hash.var_of_t State_body_hash.dummy)
          in
          let%bind () =
            with_label __LOC__ (Boolean.Assert.any [same; empty_hash])
          in
          let%bind correct_after_pop =
            with_label __LOC__
              (let%bind check =
                 Pending_coinbase.Hash.equal_var root_after_delete
                   prev_pending_coinbase_root
               in
               Boolean.if_
                 (Boolean.not ledger_hash_didn't_change)
                 ~then_:Boolean.true_ ~else_:check)
          in
          let%bind () =
            as_prover
              As_prover.(
                Let_syntax.(
                  let%map correct_after_pop =
                    read Boolean.typ correct_after_pop
                  in
                  Core.printf !"Correct after pop %b\n%!" correct_after_pop))
          in
          let%bind () = Boolean.Assert.is_true correct_after_pop in
          (*new stack or update one*)
          let%map new_root =
            with_label __LOC__
              (Pending_coinbase.Checked.add_coinbase root_after_delete
                 ( Snark_transition.proposer transition
                 , Snark_transition.coinbase_amount transition
                 , prev_state_body_hash )
                 prev_of_prev_state_hash)
            (*Not using state_body previous_state to get the hash becuase it's cheaper outside snark?*)
          in
          (new_root, deleted_stack)
        in
        let%bind correct_coinbase_status =
          let new_root =
            transition |> Snark_transition.blockchain_state
            |> Blockchain_state.staged_ledger_hash
            |> Staged_ledger_hash.pending_coinbase_hash_var
          in
          let%bind () =
            as_prover
              As_prover.(
                Let_syntax.(
                  let%map new_root =
                    read Pending_coinbase.Hash.typ new_pending_coinbase_hash
                  and new_root_expected =
                    read Pending_coinbase.Hash.typ new_root
                  in
                  Core.printf
                    !"expected PC hash %{sexp: Pending_coinbase.Hash.t} got \
                      %{sexp: Pending_coinbase.Hash.t}\n\
                     \ %!"
                    new_root_expected new_root))
          in
          Pending_coinbase.Hash.equal_var new_pending_coinbase_hash new_root
        in
        let%bind correct_transaction_snark =
          verify_complete_merge
            (Snark_transition.sok_digest transition)
            ( previous_state |> Protocol_state.blockchain_state
            |> Blockchain_state.snarked_ledger_hash )
            ( transition |> Snark_transition.blockchain_state
            |> Blockchain_state.snarked_ledger_hash )
            Pending_coinbase.Stack.Checked.empty deleted_stack supply_increase
            (As_prover.return
               (Option.value ~default:Tock.Proof.dummy
                  (Snark_transition.ledger_proof transition)))
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
                  "blockchain snark update success: $result = \
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
                    ; ("result", `Bool result) ]))
        in
        result
      in
      let new_state =
        Protocol_state.create_var ~previous_state_hash
          ~blockchain_state:(Snark_transition.blockchain_state transition)
          ~consensus_state
      in
      let%map state_hash = Protocol_state.hash_checked new_state in
      (state_hash, new_state, `Success success)
  end
end

module Checked = struct
  let%snarkydef is_base_hash h =
    Field.Checked.equal
      (Field.Var.constant
         ((Lazy.force Genesis_protocol_state.t).hash :> Field.t))
      (State_hash.var_to_hash_packed h)

  let%snarkydef hash (t : Protocol_state.var) = Protocol_state.hash_checked t
end
