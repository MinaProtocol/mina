open Core
open Receipt_chain_database_lib
module Payment = User_command

module Tree_node = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Receipt.Chain_hash.Stable.V1.t
        , Payment.Stable.V1.t )
        Tree_node.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end

module Key_value_store =
  Rocksdb.Serializable.Make
    (Receipt.Chain_hash.Stable.Latest)
    (Tree_node.Stable.Latest)

module Receipt_chain_hash = struct
  (* Receipt.Chain_hash.t is not bin_io *)
  include Receipt.Chain_hash.Stable.V1

  let empty, cons = Receipt.Chain_hash.(empty, cons)
end

include Database.Make (Payment) (Receipt_chain_hash) (Key_value_store)
