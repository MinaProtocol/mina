open Core

module type S = sig
  type root_hash

  type hash

  type account

  type key

  type token_id

  type token_id_set

  type account_id

  type account_id_set

  type index = int

  (* no deriving, purposely; signatures that include this one may add deriving *)
  type t

  module Addr : module type of Merkle_address

  module Path : Merkle_path.S with type hash := hash

  module Location : sig
    type t [@@deriving sexp, compare, hash, eq]
  end

  include
    Syncable_intf.S
    with type root_hash := root_hash
     and type hash := hash
     and type account := account
     and type addr := Addr.t
     and type path = Path.t
     and type t := t

  (** list of accounts, in increasing order of their storage locations *)
  val to_list : t -> account list

  (** the set of [account_id]s are ledger elements to skip during the fold,
      because they're in a mask
  *)
  val foldi_with_ignored_accounts :
       t
    -> account_id_set
    -> init:'accum
    -> f:(Addr.t -> 'accum -> account -> 'accum)
    -> 'accum

  val iteri : t -> f:(index -> account -> unit) -> unit

  val foldi :
    t -> init:'accum -> f:(Addr.t -> 'accum -> account -> 'accum) -> 'accum

  val fold_until :
       t
    -> init:'accum
    -> f:('accum -> account -> ('accum, 'stop) Base.Continue_or_stop.t)
    -> finish:('accum -> 'stop)
    -> 'stop

  (** set of account ids associated with accounts *)
  val accounts : t -> account_id_set

  (** Get the public key that owns a token. *)
  val token_owner : t -> token_id -> key option

  (** Get the set of all accounts which own a token. *)
  val token_owners : t -> account_id_set

  (** Get all of the tokens for which a public key has accounts. *)
  val tokens : t -> key -> token_id_set

  (** The next token that is not present in the ledger. This token will be used
      as the new token when a [Create_new_token] transaction is processed.
  *)
  val next_available_token : t -> token_id

  val set_next_available_token : t -> token_id -> unit

  val location_of_account : t -> account_id -> Location.t option

  val get_or_create_account :
    t -> account_id -> account -> ([`Added | `Existed] * Location.t) Or_error.t

  val get_or_create_account_exn :
    t -> account_id -> account -> [`Added | `Existed] * Location.t

  val close : t -> unit

  val last_filled : t -> Location.t option

  val get_uuid : t -> Uuid.t

  val get_directory : t -> string option

  val get : t -> Location.t -> account option

  val set : t -> Location.t -> account -> unit

  val set_batch : t -> (Location.t * account) list -> unit

  val get_at_index_exn : t -> int -> account

  val set_at_index_exn : t -> int -> account -> unit

  val index_of_account_exn : t -> account_id -> int

  val merkle_root : t -> root_hash

  val merkle_path : t -> Location.t -> Path.t

  val merkle_path_at_index_exn : t -> int -> Path.t

  val remove_accounts_exn : t -> account_id list -> unit
end
