module type S = sig
  module Key : Intf.Key

  module Balance : Intf.Balance

  module Account :
    Intf.Account with type key := Key.t and type balance := Balance.t

  module Hash : Intf.Hash with type account := Account.t

  module Depth : Intf.Depth
end
