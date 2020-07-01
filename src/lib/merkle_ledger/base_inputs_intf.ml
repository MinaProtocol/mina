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
