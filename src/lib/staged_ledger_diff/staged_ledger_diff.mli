module Make (Transaction_snark_work : Intf.Transaction_snark_work) :
  Intf.Make_Staged_ledger_diff(Transaction_snark_work).S

include Intf.Make_Staged_ledger_diff(Transaction_snark_work).S
