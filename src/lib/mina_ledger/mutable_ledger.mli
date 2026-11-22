open Core_kernel
open Mina_base

(** A ledger that is written to, attached to an [Immutable_ledger.t]. *)
type t

val create : parent:Immutable_ledger.t -> t

(** [freeze ~loc t] returns [t]'s ledger as an [Immutable_ledger.t], and
    orphans [t]. *)
val freeze : loc:string -> t -> Immutable_ledger.t

(** [discard ~loc t] orphans [t], throwing its writes away. *)
val discard : loc:string -> t -> unit

val depth : t -> int

val merkle_root : t -> Ledger_hash.t

val location_of_account : t -> Account_id.t -> Ledger.Location.t option

val get : t -> Ledger.Location.t -> Account.t option

val set : t -> Ledger.Location.t -> Account.t -> unit

val get_or_create_account :
     t
  -> Account_id.t
  -> Account.t
  -> ([ `Added | `Existed ] * Ledger.Location.t) Or_error.t

val unsafe_preload_accounts_from_parent : t -> Account_id.t list -> unit

(** Freezing the result orphans [ledger] too. *)
val unsafe_of_ledger : Ledger.t -> t

(** Reads through the result are not checked against [t]'s type. *)
val unsafe_to_ledger : t -> Ledger.t
