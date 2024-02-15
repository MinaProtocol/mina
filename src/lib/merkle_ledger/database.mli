module type Inputs_intf = sig
  include Base_inputs_intf.S

  module Location : Location_intf.S

  module Location_binable :
    Core_kernel.Hashable.S_binable with type t := Location.t

  module Kvdb : Intf.Key_value_database with type config := string

  module Storage_locations : Intf.Storage_locations
end

module Make (Inputs : Inputs_intf) :
  Database_intf.S
    with module Location = Inputs.Location
     and module Addr = Inputs.Location.Addr
     and type key := Inputs.Key.t
     and type token_id := Inputs.Token_id.t
     and type token_id_set := Inputs.Token_id.Set.t
     and type account := Inputs.Account.t
     and type root_hash := Inputs.Hash.t
     and type hash := Inputs.Hash.t
     and type account_id := Inputs.Account_id.t
     and type account_id_set := Inputs.Account_id.Set.t
