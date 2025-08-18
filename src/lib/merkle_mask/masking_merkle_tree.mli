module Make (I : Inputs_intf.S) :
  Masking_merkle_tree_intf.S
    with type parent := I.Base.t
     and type key := I.Key.t
     and type hash := I.Hash.t
    with module Location = I.Location
     and module Account_id := I.Account_id
     and module Token_id := I.Token_id
