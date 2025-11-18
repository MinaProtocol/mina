open Core_kernel

module type Inputs_intf = sig
  module Account : sig
    type t
  end

  module Account_id : sig
    type t

    include Comparable.S with type t := t
  end

  module Hash : sig
    type t
  end

  module Token_id : sig
    type t

    include Comparable.S with type t := t
  end

  module Location : sig
    type t

    include Comparable.S with type t := t

    module Addr : sig
      type t

      include Comparable.S with type t := t
    end
  end
end

module type Intf = sig
  type account

  type account_id

  type 'a account_id_map

  type account_id_set

  type 'a address_map

  type hash

  type location

  type 'a location_map

  type 'a token_id_map

  type t =
    { accounts : account location_map
    ; token_owners : account_id token_id_map
    ; hashes : hash address_map
    ; locations : location account_id_map
    ; non_existent_accounts : account_id_set
    }
end

module Make : functor (I : Inputs_intf) ->
  Intf
    with type account := I.Account.t
     and type account_id := I.Account_id.t
     and type 'a account_id_map := 'a I.Account_id.Map.t
     and type account_id_set := I.Account_id.Set.t
     and type 'a address_map := 'a I.Location.Addr.Map.t
     and type hash := I.Hash.t
     and type location := I.Location.t
     and type 'a location_map := 'a I.Location.Map.t
     and type 'a token_id_map := 'a I.Token_id.Map.t
