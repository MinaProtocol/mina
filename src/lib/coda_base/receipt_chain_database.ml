open Core
open Receipt_chain_database_lib
module Payment = User_command

module Tree_node = struct
  (* TODO : version *)
  type t = (Receipt.Chain_hash.Stable.V1.t, Payment.Stable.V1.t) Tree_node.t
  [@@deriving bin_io]
end

module Key_value_store =
  Rocksdb.Serializable.Make (Receipt.Chain_hash.Stable.V1) (Tree_node)

module Receipt_chain_hash = struct
  (* Receipt.Chain_hash.t is not bin_io *)
  include Receipt.Chain_hash.Stable.V1

  [%%define_locally
  Receipt.Chain_hash.(empty, cons, to_string)]
end

include Database.Make (Payment) (Receipt_chain_hash) (Key_value_store)
include Verifier.Make (Payment) (Receipt_chain_hash)
