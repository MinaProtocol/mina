(* TODO: rename *)

open Core_kernel
open Nanobit_base
open Coda_numbers
open Util
open Snark_params
open Tick
open Nanobit_base
open Let_syntax

module Make
    (Consensus_mechanism : Consensus.Mechanism.S
                           with type Proof.t = Tock.Proof.t) :
  Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism =
struct
  module Protocol_state = Consensus_mechanism.Protocol_state
  module Snark_transition = Consensus_mechanism.Snark_transition

  let check cond msg =
    if not cond then Or_error.errorf "Blockchain_state.update: %s" msg
    else Ok ()

  module type Update_intf = sig
    val update :
         Protocol_state.value
      -> Snark_transition.value
      -> Protocol_state.value Or_error.t

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
    let update state (transition: Snark_transition.value) =
      let open Or_error.Let_syntax in
      let%bind () =
        match Snark_transition.ledger_proof transition with
        | None ->
            check
              (Ledger_hash.equal
                 ( state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 ( transition |> Snark_transition.blockchain_state
                 |> Blockchain_state.ledger_hash ))
              "Body proof was none but tried to update ledger hash"
        | Some proof ->
            if Insecure.verify_blockchain then Ok ()
            else
              check
                (T.verify
                   (Transaction_snark.create
                      ~source:
                        ( state |> Protocol_state.blockchain_state
                        |> Blockchain_state.ledger_hash )
                      ~target:
                        ( transition |> Snark_transition.blockchain_state
                        |> Blockchain_state.ledger_hash )
                      ~proof_type:`Merge
                      ~fee_excess:Currency.Amount.Signed.zero ~proof))
                "Proof did not verify"
      in
      let%map consensus_state =
        Consensus_mechanism.update
          (Protocol_state.consensus_state state)
          transition
      in
      Protocol_state.create_value
        ~previous_state_hash:(Protocol_state.hash state)
        ~blockchain_state:(Snark_transition.blockchain_state transition)
        ~consensus_state

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
          ((previous_state_hash, previous_state):
            State_hash.var * Protocol_state.var)
          (transition: Snark_transition.var) :
          ( State_hash.var * Protocol_state.var * [`Success of Boolean.var]
          , _ )
          Tick.Checked.t =
        with_label __LOC__
          (let%bind good_body =
             let%bind correct_transaction_snark =
               T.verify_complete_merge
                 ( previous_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 ( transition |> Snark_transition.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 (As_prover.return
                    (Option.value ~default:Tock.Proof.dummy
                       (Snark_transition.ledger_proof transition)))
             and ledger_hash_didn't_change =
               Ledger_hash.equal_var
                 ( previous_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
                 ( transition |> Snark_transition.blockchain_state
                 |> Blockchain_state.ledger_hash )
             and consensus_data_is_valid =
               Consensus_mechanism.verify transition
             in
             let%bind correct_snark =
               Boolean.(correct_transaction_snark || ledger_hash_didn't_change)
             in
             Boolean.(correct_snark && consensus_data_is_valid)
           in
           let%bind consensus_state =
             Consensus_mechanism.update_var
               (Protocol_state.consensus_state previous_state)
               transition
           in
           let new_state =
             Protocol_state.create_var ~previous_state_hash
               ~blockchain_state:(Snark_transition.blockchain_state transition)
               ~consensus_state
           in
           let%bind state_bits = Protocol_state.var_to_bits new_state in
           let%bind state_partial =
             Pedersen_hash.Section.extend Pedersen_hash.Section.empty
               ~start:Hash_prefix.length_in_bits state_bits
           in
           let%map state_hash =
             Pedersen_hash.Section.create
               ~acc:(`Value Hash_prefix.protocol_state.acc)
               ~support:
                 (Interval_union.of_interval (0, Hash_prefix.length_in_bits))
             |> Pedersen_hash.Section.disjoint_union_exn state_partial
             >>| Pedersen_hash.Section.acc >>| Pedersen_hash.digest
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

    let hash (t: Protocol_state.var) =
      with_label __LOC__
        ( Protocol_state.var_to_bits t
        >>= digest_bits ~init:Hash_prefix.protocol_state
        >>| State_hash.var_of_hash_packed )
  end
end
