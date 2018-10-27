(* TODO: rename *)

open Core_kernel
open Snark_params
open Tick
open Coda_base
open Let_syntax

module Make (Consensus_mechanism : Consensus.Mechanism.S) :
  Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism = struct
  module Blockchain_state = Consensus_mechanism.Blockchain_state
  module Protocol_state = Consensus_mechanism.Protocol_state
  module Snark_transition = Consensus_mechanism.Snark_transition

  let check cond msg =
    if not cond then Or_error.errorf "Blockchain_state.update: %s" msg
    else Ok ()

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
      let update
          ((previous_state_hash, previous_state) :
            State_hash.var * Protocol_state.var)
          (transition : Snark_transition.var) :
          ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
          , _ )
          Tick.Checked.t =
        with_label __LOC__
          (let%bind good_body =
             let%bind correct_transaction_snark =
               T.verify_complete_merge
                 (Snark_transition.sok_digest transition)
                 ( previous_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 ( transition |> Snark_transition.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 (Snark_transition.supply_increase transition)
                 (As_prover.return
                    (Option.value ~default:Tock.Proof.dummy
                       (Snark_transition.ledger_proof transition)))
             and ledger_hash_didn't_change =
               Frozen_ledger_hash.equal_var
                 ( previous_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 ( transition |> Snark_transition.blockchain_state
                 |> Blockchain_state.ledger_hash )
             and consensus_data_is_valid =
               Consensus_mechanism.is_transition_valid_checked transition
             in
             let%bind correct_snark =
               Boolean.(correct_transaction_snark || ledger_hash_didn't_change)
             in
             Boolean.(correct_snark && consensus_data_is_valid)
           in
           let%bind consensus_state =
             Consensus_mechanism.next_state_checked
               (Protocol_state.consensus_state previous_state)
               previous_state_hash transition
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
           ( State_hash.var_of_hash_packed state_hash
           , new_state
           , `Success good_body ))
    end
  end

  module Checked = struct
    let is_base_hash h =
      with_label __LOC__
        (Field.Checked.equal
           (Field.Checked.constant
              ( Protocol_state.hash Consensus_mechanism.genesis_protocol_state
                :> Field.t ))
           (State_hash.var_to_hash_packed h))

    let hash (t : Protocol_state.var) =
      with_label __LOC__
        ( Protocol_state.var_to_triples t
        >>= Pedersen.Checked.digest_triples ~init:Hash_prefix.protocol_state
        >>| State_hash.var_of_hash_packed )
  end
end
