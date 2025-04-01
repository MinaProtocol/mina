open Async
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
  -> (User_command.Valid.t list, Verifier.Failure.t) Result.t
     Deferred.Or_error.t
