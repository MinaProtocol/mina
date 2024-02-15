module type Inputs_intf = sig
  module Location : Location_intf.S

  module Location_binable :
    Core_kernel.Hashable.S_binable with type t := Location.t

  module Key : Intf.Key

  module Token_id : Intf.Token_id

  module Account_id :
    Intf.Account_id with type key := Key.t and type token_id := Token_id.t

  module Balance : Intf.Balance

  module Account :
    Intf.Account
      with type balance := Balance.t
       and type account_id := Account_id.t
       and type token_id := Token_id.t

  module Hash : Intf.Hash with type account := Account.t

  module Base : sig
    type t

    val get : t -> Location.t -> Account.t option

    val last_filled : t -> Location.t option
  end

  val get_hash : Base.t -> Location.t -> Hash.t

  val location_of_account_addr : Location.Addr.t -> Location.t

  val location_of_hash_addr : Location.Addr.t -> Location.t

  val ledger_depth : Base.t -> int

  val set_raw_hash_batch : Base.t -> (Location.t * Hash.t) list -> unit

  val set_raw_account_batch : Base.t -> (Location.t * Account.t) list -> unit

  val set_location_batch :
       last_location:Location.t
    -> Base.t
    -> (Account_id.t * Location.t) Mina_stdlib.Nonempty_list.t
    -> unit
end

module Make (Inputs : Inputs_intf) : sig
  val get_all_accounts_rooted_at_exn :
       Inputs.Base.t
    -> Inputs.Location.Addr.t
    -> (Inputs.Location.Addr.t * Inputs.Account.t) list

  val set_hash_batch :
    Inputs.Base.t -> (Inputs.Location.t * Inputs.Hash.t) list -> unit

  val set_batch :
    Inputs.Base.t -> (Inputs.Location.t * Inputs.Account.t) list -> unit

  val set_batch_accounts :
    Inputs.Base.t -> (Inputs.Location.Addr.t * Inputs.Account.t) list -> unit

  val set_all_accounts_rooted_at_exn :
    Inputs.Base.t -> Inputs.Location.Addr.t -> Inputs.Account.t list -> unit
end
