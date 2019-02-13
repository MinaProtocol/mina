module Hashless_ledger : Transaction_logic.Ledger_intf

include
  Protocols.Coda_pow.Transaction_validator_intf
  with type ledger = Hashless_ledger.t
   and type transaction := Transaction.t
   and type user_command_with_valid_signature :=
              User_command.With_valid_signature.t
   and type ledger_hash := Ledger_hash.t
   and type outer_ledger := Ledger.t

val create : Ledger.t -> Hashless_ledger.t
