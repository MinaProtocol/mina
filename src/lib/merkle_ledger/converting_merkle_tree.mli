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

  (** The type of the converted (unstable) account in the input [Converting_ledger] *)
  type converted_account

  (** A method to convert a stable account into a Converting_ledger account *)
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
                        and type account_id_set := Inputs.Account_id.Set.t) :
  Intf.Ledger.Converting.S
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
     and type converted_account := Inputs.converted_account
     and type primary_ledger = Primary_ledger.t
     and type converting_ledger = Converting_ledger.t

module With_database_config : Intf.Ledger.Converting.Config

(** A variant of [Make] that works with DATABASE ledgers and provides checkpoint operations *)
module With_database (Inputs : sig
  include Intf.Inputs.Intf

  (** The type of the converted (unstable) account in the input [Converting_ledger] *)
  type converted_account

  (** A method to convert a stable account into a Converting_ledger account *)
  val convert : Account.t -> converted_account

  (** An [equal] method for the converted account type, used to check that  *)
  val converted_equal : converted_account -> converted_account -> bool
end)
(Primary_db : Intf.Ledger.DATABASE
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
(Converting_db : Intf.Ledger.DATABASE
                   with module Location = Inputs.Location
                    and module Addr = Inputs.Location.Addr
                    and type key := Inputs.Key.t
                    and type token_id := Inputs.Token_id.t
                    and type token_id_set := Inputs.Token_id.Set.t
                    and type account := Inputs.converted_account
                    and type root_hash := Inputs.Hash.t
                    and type hash := Inputs.Hash.t
                    and type account_id := Inputs.Account_id.t
                    and type account_id_set := Inputs.Account_id.Set.t) :
  Intf.Ledger.Converting.WITH_DATABASE
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
     and type converted_account := Inputs.converted_account
     and type primary_ledger = Primary_db.t
     and type converting_ledger = Converting_db.t
