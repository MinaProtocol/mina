open Coda_base

module Tree_node : Intf.Tree_node

module Make
    (Monad : Key_value_database.Monad.S)
    (Key_value_db : Key_value_database.Intf.S
                    with module M := Monad
                     and type key := Receipt.Chain_hash.t
                     and type value := Tree_node.t) :
  Intf.S with module M := Monad

(* A Rocksdb version of the receipt_chain_database *)
module Rocksdb :
  Key_value_database.Intf.Ident
  with type key := Receipt.Chain_hash.t
   and type value := Tree_node.t

include Intf.S with module M := Key_value_database.Monad.Ident
