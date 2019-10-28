include
  Receipt_chain_database.Intf.Read_only
  with module M := Key_value_database.Monad.Deferred
   and type config := Logger.t * int
