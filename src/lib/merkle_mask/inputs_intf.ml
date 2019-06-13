module type S = sig
  module Key : Merkle_ledger.Intf.Key

  module Balance : Merkle_ledger.Intf.Balance

  module Account :
    Merkle_ledger.Intf.Account
    with type key := Key.t
     and type balance := Balance.t

  module Hash : Merkle_ledger.Intf.Hash with type account := Account.t

  module Location : Merkle_ledger.Location_intf.S

  module Base :
    Base_merkle_tree_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and type account := Account.t
     and type root_hash := Hash.t
     and type hash := Hash.t
     and type key := Key.t
     and type key_set := Key.Set.t
end
