open Core

module type Key = sig
  type t [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, bin_io]
    end

    module Latest = V1
  end
  with type V1.t = t

  val empty : t

  val to_string : t -> string

  include Hashable.S_binable with type t := t

  include Comparable.S with type t := t
end

module type Token_id = sig
  type t [@@deriving sexp]

  module Stable : sig
    module Latest : sig
      type t [@@deriving bin_io]
    end
  end
  with type Latest.t = t

  val default : t

  include Hashable.S_binable with type t := t

  include Comparable.S_binable with type t := t
end

module type Account_id = sig
  type key

  type token_id

  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving sexp]
    end
  end]

  val public_key : t -> key

  val token_id : t -> token_id

  val create : key -> token_id -> t

  val derive_token_id : owner:t -> token_id

  include Hashable.S_binable with type t := t

  include Comparable.S with type t := t
end

module type Balance = sig
  type t [@@deriving equal]

  val zero : t

  val to_int : t -> int
end

module type Account = sig
  type t [@@deriving bin_io, equal, sexp, compare]

  type token_id

  type account_id

  type balance

  val token : t -> token_id

  val identifier : t -> account_id

  val balance : t -> balance

  val empty : t
end

module type Hash = sig
  type t [@@deriving bin_io, compare, equal, sexp, yojson]

  val to_base58_check : t -> string

  include Hashable.S_binable with type t := t

  type account

  val merge : height:int -> t -> t -> t

  val hash_account : account -> t

  val empty_account : t
end

module type Depth = sig
  val depth : int
end

module type Key_value_database = sig
  type t [@@deriving sexp]

  type config

  include
    Key_value_database.Intf.Ident
      with type t := t
       and type key := Bigstring.t
       and type value := Bigstring.t
       and type config := config

  val create_checkpoint : t -> string -> t

  val make_checkpoint : t -> string -> unit

  val get_uuid : t -> Uuid.t

  val set_batch :
       t
    -> ?remove_keys:Bigstring.t list
    -> key_data_pairs:(Bigstring.t * Bigstring.t) list
    -> unit

  (** An association list, sorted by key *)
  val to_alist : t -> (Bigstring.t * Bigstring.t) list

  val foldi :
       t
    -> init:'a
    -> f:(int -> 'a -> key:Bigstring.t -> data:Bigstring.t -> 'a)
    -> 'a

  val fold_until :
       t
    -> init:'a
    -> f:
         (   'a
          -> key:Bigstring.t
          -> data:Bigstring.t
          -> ('a, 'b) Continue_or_stop.t )
    -> finish:('a -> 'b)
    -> 'b
end

module type Storage_locations = sig
  val key_value_db_dir : string
end

module Inputs = struct
  module type Intf = sig
    module Key : Key

    module Token_id : Token_id

    module Account_id :
      Account_id with type key := Key.t and type token_id := Token_id.t

    module Balance : Balance

    module Account :
      Account
        with type token_id := Token_id.t
         and type account_id := Account_id.t
         and type balance := Balance.t

    module Hash : Hash with type account := Account.t

    module Location : Location_intf.S
  end

  module type DATABASE = sig
    include Intf

    module Location_binable :
      Core_kernel.Hashable.S_binable with type t := Location.t

    module Kvdb : Key_value_database with type config := string

    module Storage_locations : Storage_locations
  end
end

module Ledger = struct
  module type S = sig
    (** a Merkle hash associated with the root node *)
    type root_hash

    (** a Merkle hash associated any non-root node *)
    type hash

    type account

    type key

    type token_id

    type token_id_set

    type account_id

    type account_id_set

    type index = int

    (** no deriving, purposely; signatures that include this one may add deriving *)
    type t

    module Addr : module type of Merkle_address

    module Path : Merkle_path.S with type hash := hash

    module Location : sig
      type t [@@deriving sexp, compare, hash]

      include Comparable.S with type t := t
    end

    include
      Syncable_intf.S
        with type root_hash := root_hash
         and type hash := hash
         and type account := account
         and type addr := Addr.t
         and type path = Path.t
         and type t := t

    (** list of accounts in the ledger *)
    val to_list : t -> account list Async.Deferred.t

    (** list of accounts via slower sequential mechanism *)
    val to_list_sequential : t -> account list

    (** iterate over all indexes and accounts *)
    val iteri : t -> f:(index -> account -> unit) -> unit

    (** fold over accounts in the ledger, passing the Merkle address *)
    val foldi :
      t -> init:'accum -> f:(Addr.t -> 'accum -> account -> 'accum) -> 'accum

    (** the set of [account_id]s are ledger elements to skip during the fold,
      because they're in a mask
  *)
    val foldi_with_ignored_accounts :
         t
      -> account_id_set
      -> init:'accum
      -> f:(Addr.t -> 'accum -> account -> 'accum)
      -> 'accum

    (** fold over accounts until stop condition reached when calling [f]; calls [finish] for
     result
 *)
    val fold_until :
         t
      -> init:'accum
      -> f:('accum -> account -> ('accum, 'stop) Base.Continue_or_stop.t)
      -> finish:('accum -> 'stop)
      -> 'stop Async.Deferred.t

    (** set of account ids associated with accounts *)
    val accounts : t -> account_id_set Async.Deferred.t

    (** Get the account id that owns a token. *)
    val token_owner : t -> token_id -> account_id option

    (** Get the set of all accounts which own a token. *)
    val token_owners : t -> account_id_set

    (** Get all of the tokens for which a public key has accounts. *)
    val tokens : t -> key -> token_id_set

    val location_of_account : t -> account_id -> Location.t option

    val location_of_account_batch :
      t -> account_id list -> (account_id * Location.t option) list

    (** This may return an error if the ledger is full. *)
    val get_or_create_account :
         t
      -> account_id
      -> account
      -> ([ `Added | `Existed ] * Location.t) Or_error.t

    (** the ledger should not be used after calling [close] *)
    val close : t -> unit

    (** for account locations in the ledger, the last (rightmost) filled location *)
    val last_filled : t -> Location.t option

    val get_uuid : t -> Uuid.t

    (** return Some [directory] for ledgers that use a file system, else None *)
    val get_directory : t -> string option

    val get : t -> Location.t -> account option

    val get_batch : t -> Location.t list -> (Location.t * account option) list

    val set : t -> Location.t -> account -> unit

    val set_batch : t -> (Location.t * account) list -> unit

    val get_at_index_exn : t -> int -> account

    val set_at_index_exn : t -> int -> account -> unit

    val index_of_account_exn : t -> account_id -> int

    (** meant to be a fast operation: the root hash is stored, rather
      than calculated dynamically
  *)
    val merkle_root : t -> root_hash

    val merkle_path : t -> Location.t -> Path.t

    val merkle_path_at_index_exn : t -> int -> Path.t

    val merkle_path_batch : t -> Location.t list -> Path.t list

    val wide_merkle_path_batch :
         t
      -> Location.t list
      -> [ `Left of hash * hash | `Right of hash * hash ] list list

    val get_hash_batch_exn : t -> Location.t list -> hash list

    (** Triggers when the ledger has been detached and should no longer be
      accessed.
  *)
    val detached_signal : t -> unit Async_kernel.Deferred.t
  end

  module type NULL = sig
    include S

    val create : depth:int -> unit -> t
  end

  module type ANY = sig
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
      S
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

  module type DATABASE = sig
    include S

    val create : ?directory_name:string -> depth:int -> unit -> t

    (** create_checkpoint would create the checkpoint and open a db connection to that checkpoint *)
    val create_checkpoint : t -> directory_name:string -> unit -> t

    (** make_checkpoint would only create the checkpoint *)
    val make_checkpoint : t -> directory_name:string -> unit

    val with_ledger : depth:int -> f:(t -> 'a) -> 'a

    module For_tests : sig
      val gen_account_location :
        ledger_depth:int -> Location.t Core.Quickcheck.Generator.t
    end
  end
end
