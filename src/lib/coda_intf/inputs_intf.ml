open Core_intf
open Staged_ledger_intf
open Transition_intf

module type Inputs_intf = sig
  module Ledger_proof : Ledger_proof_intf

  module Verifier : Verifier_intf with type ledger_proof := Ledger_proof.t

  module Transaction_snark_work :
    Transaction_snark_work_intf with type ledger_proof := Ledger_proof.t

  module Staged_ledger_diff :
    Staged_ledger_diff_intf
    with type transaction_snark_work := Transaction_snark_work.t
     and type transaction_snark_work_checked :=
                Transaction_snark_work.Checked.t

  module Staged_ledger :
    Staged_ledger_intf
    with type diff := Staged_ledger_diff.t
     and type valid_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type transaction_snark_work := Transaction_snark_work.t
     and type transaction_snark_work_statement :=
                Transaction_snark_work.Statement.t
     and type transaction_snark_work_checked :=
                Transaction_snark_work.Checked.t
     and type verifier := Verifier.t
     and type ledger_proof := Ledger_proof.t

  module Internal_transition :
    Internal_transition_intf
    with type staged_ledger_diff := Staged_ledger_diff.t

  module External_transition :
    External_transition_intf
    with type verifier := Verifier.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type ledger_proof := Ledger_proof.t
end
