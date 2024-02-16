module type S = sig
  type addr

  type ledger

  type t

  (* Visualize will enumerate through all edges of a subtree with a
     initial_address. It will then interpret all of the edges and nodes into an
     intermediate form that will be easy to write into a dot file *)
  val visualize : ledger -> initial_address:addr -> t

  (* Write will transform the intermediate form generate by visualize and save
     the results into a dot file *)
  val write : path:string -> name:string -> t -> unit Async.Deferred.t
end

module type Inputs_intf = sig
  module Key : Intf.Key

  module Token_id : Intf.Token_id

  module Account_id :
    Intf.Account_id with type key := Key.t and type token_id := Token_id.t

  module Balance : Intf.Balance

  module Account :
    Intf.Account
      with type account_id := Account_id.t
       and type balance := Balance.t

  module Hash : Intf.Hash with type account := Account.t

  module Location : Location_intf.S

  module Ledger :
    Intf.Ledger.S
      with module Addr = Location.Addr
       and module Location = Location
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type account := Account.t
end
