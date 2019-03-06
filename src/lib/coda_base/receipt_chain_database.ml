open Core
open Receipt_chain_database_lib
module Payment = User_command

module Tree_node = struct
  type t = (Receipt.Chain_hash.t, Payment.t) Tree_node.t [@@deriving bin_io]
end

module Key_value_store =
  Rocksdb.Serializable.Make (Receipt.Chain_hash) (Tree_node)
include Database.Make (Payment) (Receipt.Chain_hash) (Key_value_store)
