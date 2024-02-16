module type S = sig
  module Key : Intf.Key

  module Token_id : Intf.Token_id

  module Account_id :
    Intf.Account_id with type key := Key.t and type token_id := Token_id.t

  module Balance : Intf.Balance

  module Account :
    Intf.Account
      with type token_id := Token_id.t
       and type account_id := Account_id.t
       and type balance := Balance.t

  module Hash : Intf.Hash with type account := Account.t
end

module type Intf = sig
  include S

  module Location : Location_intf.S
end

module type DATABASE = sig
  include Intf

  module Location_binable :
    Core_kernel.Hashable.S_binable with type t := Location.t

  module Kvdb : Intf.Key_value_database with type config := string

  module Storage_locations : Intf.Storage_locations
end
