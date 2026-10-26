open Core_kernel

module type Inputs_intf = sig
  module Location : Location_intf.S

  module Location_binable : Hashable.S_binable with type t := Location.t

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

  (** Write the accounts at their locations, and update the indexes kept for
      the accounts that [reindex] selects. *)
  val set_raw_account_batch :
       reindex:(Location.t * Account.t -> bool)
    -> Base.t
    -> (Location.t * Account.t) list
    -> unit

  val set_location_batch :
       last_location:Location.t
    -> Base.t
    -> (Account_id.t * Location.t) Mina_stdlib.Nonempty_list.t
    -> unit
end

module type S = sig
  type base

  type location

  type addr

  type account

  type hash

  type hash_cache

  val get_all_accounts_rooted_at_exn : base -> addr -> (addr * account) list

  val set_hash_batch : base -> (location * hash) list -> unit

  val set_batch :
    ?hash_cache:hash_cache -> base -> (location * account) list -> unit

  (** [set_batch], updating the indexes kept for an account only if [reindex]
      selects it: an account replacing one with the same identifier keeps the
      entries of the one it replaces. *)
  val set_batch_reindexing :
       ?hash_cache:hash_cache
    -> reindex:(location * account -> bool)
    -> base
    -> (location * account) list
    -> unit

  val set_batch_accounts : base -> (addr * account) list -> unit

  val set_all_accounts_rooted_at_exn : base -> addr -> account list -> unit
end

module Make (Inputs : Inputs_intf) :
  S
    with type base := Inputs.Base.t
     and type location := Inputs.Location.t
     and type addr := Inputs.Location.Addr.t
     and type account := Inputs.Account.t
     and type hash := Inputs.Hash.t
     and type hash_cache := Inputs.Hash.t Inputs.Location.Addr.Map.t
