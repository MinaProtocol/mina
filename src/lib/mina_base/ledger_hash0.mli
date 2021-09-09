(* This module exists to break the dependency cycle

   Snapp_account
   -> Ledger_hash
   -> Account
   -> Snapp_account *)
include Ledger_hash_intf0.S
