module Make (Inputs : Coda_intf.Tmp_test_stub_hack.For_staged_ledger_intf) :
  Coda_intf.Staged_ledger_generalized_intf
  with type diff := Inputs.Staged_ledger_diff.t
   and type valid_diff :=
              Inputs.Staged_ledger_diff.With_valid_signatures_and_proofs.t
   and type ledger_proof := Inputs.Ledger_proof.t
   and type verifier := Inputs.Verifier.t
   and type transaction_snark_work := Inputs.Transaction_snark_work.t
   and type transaction_snark_work_statement :=
              Inputs.Transaction_snark_work.Statement.t
   and type transaction_snark_work_checked :=
              Inputs.Transaction_snark_work.Checked.t
   and type transaction_snark_statement := Transaction_snark.Statement.t

include
  Coda_intf.Staged_ledger_intf
  with type diff := Staged_ledger_diff.t
   and type valid_diff := Staged_ledger_diff.With_valid_signatures_and_proofs.t
   and type ledger_proof := Ledger_proof.t
   and type transaction_snark_work := Transaction_snark_work.t
   and type transaction_snark_work_statement :=
              Transaction_snark_work.Statement.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t
   and type verifier := Verifier.t
