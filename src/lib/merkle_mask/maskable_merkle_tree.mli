module type Inputs_intf = sig
  include Inputs_intf.S

  module Mask :
    Masking_merkle_tree_intf.S
      with type account := Account.t
       and type hash := Hash.t
       and type key := Key.t
       and type parent := Base.t
      with module Location = Location
       and module Token_id := Token_id
       and module Account_id := Account_id

  val mask_to_base : Mask.Attached.t -> Base.t
end

module Make (I : Inputs_intf) :
  Maskable_merkle_tree_intf.S
    with type root_hash := I.Hash.t
     and type hash := I.Hash.t
     and type account := I.Account.t
     and type key := I.Key.t
     and type t := I.Base.t
     and type unattached_mask := I.Mask.t
     and type attached_mask := I.Mask.Attached.t
     and type accumulated_t := I.Mask.accumulated_t
    with module Location = I.Location
     and module Addr = I.Location.Addr
     and module Token_id := I.Token_id
     and module Account_id := I.Account_id
