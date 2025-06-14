(** Create a merkle tree implementation that proxies through to
    [Primary_ledger] for all reads and writes, but also updates the
    [Converting_ledger] on every mutation.

    The goal of this is to make it easy to upgrade ledgers for breaking changes
    to the merkle tree. A running daemon can use this to keep track of ledgers
    as normal, but can also retrieve the [Converting_ledger] so that it may be
    used for an automated switch-over at upgrade time.
*)
module Make (Inputs : sig
  include Intf.Inputs.Intf

  type converted_account

  val convert : Account.t -> converted_account
end)
(Primary_ledger : Intf.Ledger.S
                    with module Location = Inputs.Location
                     and module Addr = Inputs.Location.Addr
                     and type key := Inputs.Key.t
                     and type token_id := Inputs.Token_id.t
                     and type token_id_set := Inputs.Token_id.Set.t
                     and type account := Inputs.Account.t
                     and type root_hash := Inputs.Hash.t
                     and type hash := Inputs.Hash.t
                     and type account_id := Inputs.Account_id.t
                     and type account_id_set := Inputs.Account_id.Set.t)
(Converting_ledger : Intf.Ledger.S
                       with module Location = Inputs.Location
                        and module Addr = Inputs.Location.Addr
                        and type key := Inputs.Key.t
                        and type token_id := Inputs.Token_id.t
                        and type token_id_set := Inputs.Token_id.Set.t
                        and type account := Inputs.converted_account
                        and type root_hash := Inputs.Hash.t
                        and type hash := Inputs.Hash.t
                        and type account_id := Inputs.Account_id.t
                        and type account_id_set := Inputs.Account_id.Set.t) : sig
  include
    Intf.Ledger.S
      with module Location = Inputs.Location
       and module Addr = Inputs.Location.Addr
       and type key := Inputs.Key.t
       and type token_id := Inputs.Token_id.t
       and type token_id_set := Inputs.Token_id.Set.t
       and type account := Inputs.Account.t
       and type root_hash := Inputs.Hash.t
       and type hash := Inputs.Hash.t
       and type account_id := Inputs.Account_id.t
       and type account_id_set := Inputs.Account_id.Set.t

  val create : Primary_ledger.t -> Converting_ledger.t -> t

  (** Create a converting ledger with an already-existing [Primary_ledger.t] and
      an empty [Converting_ledger.t] that will be initialized with the migrated
      account data. *)
  val create_with_migration : Primary_ledger.t -> Converting_ledger.t -> t

  val primary_ledger : t -> Primary_ledger.t

  val converting_ledger : t -> Converting_ledger.t

  val convert : Inputs.Account.t -> Inputs.converted_account
end
