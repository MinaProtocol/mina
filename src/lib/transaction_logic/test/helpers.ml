module Ledger = Mina_ledger.Ledger.Ledger_inner
module Transaction_logic = Mina_transaction_logic.Make (Ledger)

module Zk_cmd_result = struct
  type t =
    Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.t
    * Ledger.t

  let sexp_of_t (txn, _) =
    Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.sexp_of_t
      txn
end
