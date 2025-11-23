open Core_kernel

module type Inputs_intf = sig
  module Account : T

  module Account_id : Comparable.S

  module Hash : T

  module Token_id : Comparable.S

  module Location : sig
    include Comparable.S

    module Addr : Comparable.S
  end
end

module type S = sig
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
