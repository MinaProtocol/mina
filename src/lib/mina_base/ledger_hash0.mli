(* This module exists to break the dependency cycle

   Zkapp_account
   -> Ledger_hash
   -> Account
   -> Zkapp_account *)
include Ledger_hash_intf0.S
