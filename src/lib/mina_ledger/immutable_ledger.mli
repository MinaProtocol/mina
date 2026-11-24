open Mina_base

(** A ledger that is only read. Each block's ledger is one, attached to the
    ledger of the block before it. *)
type t

val of_any_ledger : Ledger.Any_ledger.witness -> t

val depth : t -> int

val merkle_root : t -> Ledger_hash.t

val num_accounts : t -> int

val location_of_account : t -> Account_id.t -> Ledger.Location.t option

val get : t -> Ledger.Location.t -> Account.t option

val to_list : t -> Account.t list Async_kernel.Deferred.t

(** [commit_into_parent ~loc t ~parent] commits [t] into its parent [parent],
    then makes [t] hold [parent]'s ledger and orphans [parent]. *)
val commit_into_parent : loc:string -> t -> parent:t -> unit

val unsafe_of_ledger : Ledger.t -> t

(** Writes through the result are not checked against [t]'s type. *)
val unsafe_to_ledger : t -> Ledger.t
