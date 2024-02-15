module type Inputs_intf = sig
  include Base_inputs_intf.S

  module Location : Location_intf.S
end

module Make (Inputs : Inputs_intf) : sig
  include
    Base_ledger_intf.S
      with module Addr = Inputs.Location.Addr
      with module Location = Inputs.Location
      with type key := Inputs.Key.t
       and type token_id := Inputs.Token_id.t
       and type token_id_set := Inputs.Token_id.Set.t
       and type account_id := Inputs.Account_id.t
       and type account_id_set := Inputs.Account_id.Set.t
       and type hash := Inputs.Hash.t
       and type root_hash := Inputs.Hash.t
       and type account := Inputs.Account.t

  val create : depth:int -> unit -> t
end
