(* TODO: rename *)

open Core_kernel
open Snark_params
open Tick
open Coda_base
open Let_syntax

module Make (Consensus_mechanism : Consensus.S) :
  Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism = struct
  module Blockchain_state = Consensus_mechanism.Blockchain_state
  module Protocol_state = Consensus_mechanism.Protocol_state
  module Snark_transition = Consensus_mechanism.Snark_transition

  module type Update_intf = sig
    module Checked : sig
      val update :
           State_hash.var * Protocol_state.var
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
        | "full" -> T.verify_complete_merge
        | _ -> fun _ _ _ _ _ _ _ -> Checked.return Boolean.true_

      let%snarkydef update
          ((previous_state_hash, previous_state) :
            State_hash.var * Protocol_state.var)
          (transition : Snark_transition.var) :
          ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
          , _ )
          Tick.Checked.t =
        let supply_increase = Snark_transition.supply_increase transition in
        let%bind `Success updated_consensus_state, consensus_state =
          Consensus_mechanism.next_state_checked ~prev_state:previous_state
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
            (*new stack or update one*)
            let%bind coinbase_amount =
              exists Currency.Amount.typ
                ~compute:
                  As_prover.(
                    map get_state ~f:(fun _ ->
                        Protocols.Coda_praos.coinbase_amount ))
            in
            let%map new_root =
              Pending_coinbase.Checked.add_coinbase root_after_delete
                (Snark_transition.proposer transition, coinbase_amount)
            in
            (new_root, deleted_stack)
          in
          let%bind correct_coinbase_status =
            let new_root =
              transition |> Snark_transition.blockchain_state
              |> Blockchain_state.staged_ledger_hash
              |> Staged_ledger_hash.pending_coinbase_hash_var
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
              Pending_coinbase.Stack.Checked.empty deleted_stack
              supply_increase
              (As_prover.return
                 (Option.value ~default:Tock.Proof.dummy
                    (Snark_transition.ledger_proof transition)))
          in
          let%bind correct_snark =
            Boolean.(correct_transaction_snark || nothing_changed)
          in
          Boolean.all
            [correct_snark; updated_consensus_state; correct_coinbase_status]
        in
        let new_state =
          Protocol_state.create_var ~previous_state_hash
            ~blockchain_state:(Snark_transition.blockchain_state transition)
            ~consensus_state
        in
        let%bind state_triples = Protocol_state.var_to_triples new_state in
        let%bind state_partial =
          Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty
            ~start:Hash_prefix.length_in_triples state_triples
        in
        let%map state_hash =
          Pedersen.Checked.Section.create
            ~acc:(`Value Hash_prefix.protocol_state.acc)
            ~support:
              (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
          |> Pedersen.Checked.Section.disjoint_union_exn state_partial
          >>| Pedersen.Checked.Section.to_initial_segment_digest_exn >>| fst
        in
        (State_hash.var_of_hash_packed state_hash, new_state, `Success success)
    end
  end

  module Checked = struct
    let%snarkydef is_base_hash h =
      Field.Checked.equal
        (Field.Var.constant
           (Consensus_mechanism.genesis_protocol_state.hash :> Field.t))
        (State_hash.var_to_hash_packed h)

    let%snarkydef hash (t : Protocol_state.var) =
      Protocol_state.var_to_triples t
      >>= Pedersen.Checked.digest_triples ~init:Hash_prefix.protocol_state
      >>| State_hash.var_of_hash_packed
  end
end
