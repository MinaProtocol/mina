val make_account :
     Signature_lib.Public_key.Compressed.t
  -> int
  -> Intf.Public_accounts.account_data

val balance_gen : int Core_kernel.Quickcheck.Generator.t

val gen : Intf.Public_accounts.account_data Core_kernel__Quickcheck.Generator.t
