open Core
open Async
open Receipt_chain_database_lib
open Storage.Disk

module Payment = struct
  include User_command
  include Hashable.Make_binable (User_command)
end

module Tree_node = struct
  type t = (Receipt.Chain_hash.t, Payment.t) Tree_node.t [@@deriving bin_io]
end

module Key_value_store =
  Key_value_database.Make_mock (Receipt.Chain_hash) (Tree_node)
include Database.Make (Payment) (Receipt.Chain_hash) (Key_value_store)
