module type S = sig
  module Key : Merkle_ledger.Intf.Key

  module Token_id : Merkle_ledger.Intf.Token_id

  module Account_id :
    Merkle_ledger.Intf.Account_id
    with type key := Key.t
     and type token_id := Token_id.t

  module Balance : Merkle_ledger.Intf.Balance

  module Account :
    Merkle_ledger.Intf.Account
    with type token_id := Token_id.t
     and type account_id := Account_id.t
     and type balance := Balance.t

  module Hash : Merkle_ledger.Intf.Hash with type account := Account.t

  module Location : Merkle_ledger.Location_intf.S

  module Location_binable :
    Core_kernel.Hashable.S_binable with type t := Location.t

  module Base :
    Base_merkle_tree_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and type account := Account.t
     and type root_hash := Hash.t
     and type hash := Hash.t
     and type key := Key.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
end
