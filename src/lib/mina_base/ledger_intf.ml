open Core_kernel

type account_state = [ `Added | `Existed ] [@@deriving equal]

module type S = sig
  type t

  type location

  val get : t -> location -> Account.t option

  val location_of_account : t -> Account_id.t -> location option

  val set : t -> location -> Account.t -> unit

  val get_or_create :
    t -> Account_id.t -> (account_state * Account.t * location) Or_error.t

  val create_new_account : t -> Account_id.t -> Account.t -> unit Or_error.t

  val remove_accounts_exn : t -> Account_id.t list -> unit

  val merkle_root : t -> Ledger_hash.t

  val with_ledger : depth:int -> f:(t -> 'a) -> 'a

  val empty : depth:int -> unit -> t

  val create_masked : t -> t

  val apply_mask : t -> masked:t -> unit
end
