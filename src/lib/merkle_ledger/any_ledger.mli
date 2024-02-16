module type S = sig
  type key

  type token_id

  type token_id_set

  type account_id

  type account_id_set

  type account

  type hash

  module Location : Location_intf.S

  (** The type of the witness for a base ledger exposed here so that it can
   * be easily accessed from outside this module *)
  type witness [@@deriving sexp_of]

  module type Base_intf =
    Base_ledger_intf.S
      with module Addr = Location.Addr
      with module Location = Location
      with type key := key
       and type token_id := token_id
       and type token_id_set := token_id_set
       and type account_id := account_id
       and type account_id_set := account_id_set
       and type hash := hash
       and type root_hash := hash
       and type account := account

  val cast : (module Base_intf with type t = 'a) -> 'a -> witness

  module M : Base_intf with type t = witness
end

module Make_base (Inputs : Base_inputs_intf.Intf) :
  S
    with module Location = Inputs.Location
    with type key := Inputs.Key.t
     and type token_id := Inputs.Token_id.t
     and type token_id_set := Inputs.Token_id.Set.t
     and type account_id := Inputs.Account_id.t
     and type hash := Inputs.Hash.t
     and type account_id_set := Inputs.Account_id.Set.t
     and type account := Inputs.Account.t
