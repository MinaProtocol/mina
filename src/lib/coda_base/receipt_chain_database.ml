open Core
open Receipt_chain_database_lib

module Payment = struct
  include Payment

  type payload = Payload.Stable.V1.t

  let payload {payload; _} = payload
end

module Tree_node = struct
  type t = (Receipt.Chain_hash.t, Payment.t) Tree_node.t
end

module Key_value_store =
  Key_value_database.Make_mock (Receipt.Chain_hash) (Tree_node)
include Database.Make (Payment) (Receipt.Chain_hash) (Key_value_store)
