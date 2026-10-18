module Make : functor (I : Mask_maps_intf.Inputs_intf) ->
  Mask_maps_intf.S
    with type account := I.Account.t
     and type account_id := I.Account_id.t
     and type 'a account_id_map := 'a I.Account_id.Map.t
     and type account_id_set := I.Account_id.Set.t
     and type 'a address_map := 'a I.Location.Addr.Map.t
     and type hash := I.Hash.t
     and type location := I.Location.t
     and type 'a location_map := 'a I.Location.Map.t
     and type 'a token_id_map := 'a I.Token_id.Map.t
