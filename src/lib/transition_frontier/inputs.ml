open Core_kernel
open Protocols.Coda_pow
open Coda_base
open Signature_lib

module type Inputs_intf = sig
  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Pending_coinbase_stack_state :
    Pending_coinbase_stack_state_intf
    with type pending_coinbase_stack := Pending_coinbase.Stack.t

  module Ledger_proof_statement :
    Ledger_proof_statement_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type pending_coinbase_stack_state := Pending_coinbase_stack_state.t

  module Ledger_proof : sig
    include
      Ledger_proof_intf
      with type statement := Ledger_proof_statement.t
       and type ledger_hash := Frozen_ledger_hash.t
       and type proof := Proof.t
       and type sok_digest := Sok_message.Digest.t

    include Sexpable.S with type t := t
  end

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Public_key.Compressed.t

  module Staged_ledger_diff :
    Staged_ledger_diff_intf
    with type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type fee_transfer_single := Fee_transfer.single

  module External_transition :
    External_transition.S
    with module Protocol_state = Consensus.Protocol_state
     and module Staged_ledger_diff := Staged_ledger_diff

  module Transaction_witness :
    Transaction_witness_intf with type sparse_ledger := Sparse_ledger.t

  module Staged_ledger :
    Staged_ledger_intf
    with type diff := Staged_ledger_diff.t
     and type valid_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type ledger := Ledger.t
     and type ledger_proof := Ledger_proof.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type sparse_ledger := Sparse_ledger.t
     and type ledger_proof_statement := Ledger_proof_statement.t
     and type ledger_proof_statement_set := Ledger_proof_statement.Set.t
     and type transaction := Transaction.t
     and type user_command := User_command.t
     and type transaction_witness := Transaction_witness.t
     and type pending_coinbase_collection := Pending_coinbase.t
     and type pending_coinbase_update := Pending_coinbase_update.t

  val max_length : int
end
