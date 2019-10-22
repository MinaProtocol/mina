open Coda_base

module Tree_node : Intf.Tree_node

module Make
    (Key_value_db : Key_value_database.S
                    with type key := Receipt.Chain_hash.t
                     and type value := Tree_node.t) : Intf.S

(* A Rocksdb version of the receipt_chain_database *)
module Rocksdb :
  Key_value_database.S
  with type key := Receipt.Chain_hash.t
   and type value := Tree_node.t

include Intf.S
