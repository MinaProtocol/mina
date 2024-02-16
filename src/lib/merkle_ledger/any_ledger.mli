module Make_base (Inputs : Base_inputs_intf.Intf) :
  Base_ledger_intf.ANY
    with module Location = Inputs.Location
    with type key := Inputs.Key.t
     and type token_id := Inputs.Token_id.t
     and type token_id_set := Inputs.Token_id.Set.t
     and type account_id := Inputs.Account_id.t
     and type hash := Inputs.Hash.t
     and type account_id_set := Inputs.Account_id.Set.t
     and type account := Inputs.Account.t
