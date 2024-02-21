module type Inputs_intf = sig
  include Inputs_intf.S

  module Mask :
    Masking_merkle_tree_intf.S
      with module Location = Location
       and type account := Account.t
       and type location := Location.t
       and type hash := Hash.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type parent := Base.t

  val mask_to_base : Mask.Attached.t -> Base.t
end

module Make (I : Inputs_intf) :
  Maskable_merkle_tree_intf.S
    with module Location = I.Location
     and module Addr = I.Location.Addr
     and type t := I.Base.t
     and type root_hash := I.Hash.t
     and type hash := I.Hash.t
     and type account := I.Account.t
     and type key := I.Key.t
     and type token_id := I.Token_id.t
     and type token_id_set := I.Token_id.Set.t
     and type account_id := I.Account_id.t
     and type account_id_set := I.Account_id.Set.t
     and type unattached_mask := I.Mask.t
     and type attached_mask := I.Mask.Attached.t
     and type accumulated_t := I.Mask.accumulated_t
