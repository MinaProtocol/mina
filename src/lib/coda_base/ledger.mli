open Core
open Signature_lib

module Location : Merkle_ledger.Location_intf.S

module Db :
  Merkle_ledger.Database_intf.S
  with module Location = Location
  with module Addr = Location.Addr
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t

module Any_ledger :
  Merkle_ledger.Any_ledger.S
  with module Location = Location
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t

module Mask :
  Merkle_mask.Masking_merkle_tree_intf.S
  with module Location = Location
   and module Attached.Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t
   and type location := Location.t
   and type parent := Any_ledger.M.t

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location = Location
  with module Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t
   and type root_hash := Ledger_hash.t
   and type unattached_mask := Mask.t
   and type attached_mask := Mask.Attached.t
   and type t := Any_ledger.M.t

include
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location := Location
  with module Addr = Location.Addr
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type t = Mask.Attached.t
   and type attached_mask = Mask.Attached.t
   and type unattached_mask = Mask.t

(* The maskable ledger is t = Mask.Attached.t because register/unregister
 * work off of this type *)
type maskable_ledger = t

(* TODO: Actually implement serializable properly #1206 *)
include
  Protocols.Coda_pow.Mask_serializable_intf
  with type serializable = int
   and type t := t
   and type unattached_mask := unattached_mask

val with_ledger : f:(t -> 'a) -> 'a

val with_ephemeral_ledger : f:(t -> 'a) -> 'a

val create : ?directory_name:string -> unit -> t

val create_ephemeral : unit -> t

val of_database : Db.t -> t

val copy : t -> t
(** This is not _really_ copy, merely a stop-gap until we remove usages of copy in our codebase. What this actually does is creates a new empty mask on top of the current ledger *)

val register_mask : t -> Mask.t -> Mask.Attached.t

val commit : Mask.Attached.t -> unit

module Undo : sig
  module User_command : sig
    module Common : sig
      type t =
        { user_command: User_command.t
        ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
    end

    module Body : sig
      type t =
        | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
        | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
    end

    type t = {common: Common.t; body: Body.t} [@@deriving sexp, bin_io]
  end

  type fee_transfer =
    { fee_transfer: Fee_transfer.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type coinbase =
    { coinbase: Coinbase.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type varying =
    | User_command of User_command.t
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, bin_io]

  type t = {previous_hash: Ledger_hash.t; varying: varying} [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, sexp]
      end

      module Latest = V1
    end
    with type V1.t = t

  val transaction : t -> Transaction.t Or_error.t
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_user_command :
  t -> User_command.With_valid_signature.t -> Undo.User_command.t Or_error.t

val apply_transaction : t -> Transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_user_command_exn :
  t -> User_command.With_valid_signature.t -> Ledger_hash.t

val create_empty : t -> Public_key.Compressed.t -> Path.t * Account.t

val num_accounts : t -> int
