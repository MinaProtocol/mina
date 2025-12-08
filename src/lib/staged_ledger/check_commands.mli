open Mina_base
module Ledger = Mina_ledger.Ledger

type transaction_pool_proxy =
  { find_by_hash :
         Mina_transaction.Transaction_hash.t
      -> Mina_transaction.Transaction_hash.User_command_with_valid_signature.t
         option
  }

val dummy_transaction_pool_proxy : transaction_pool_proxy

val check_commands :
     Ledger.t
  -> verifier:Verifier.t
  -> transaction_pool_proxy:transaction_pool_proxy
  -> User_command.t With_status.t list
  -> Mina_transaction.Transaction_hash.t list
  -> ( ( Signed_command.With_valid_signature.t
       , Zkapp_command.Valid.t )
       User_command.t_
       list
     , Verifier.Failure.t )
     result
     Async_kernel.Deferred.Or_error.t
