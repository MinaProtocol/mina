open Core_kernel

module type LOCATION = sig
  module Addr : module type of Merkle_address

  module Prefix : sig
    val generic : Unsigned.UInt8.t

    val account : Unsigned.UInt8.t

    val hash : ledger_depth:int -> int -> Unsigned.UInt8.t
  end

  type t = Generic of Bigstring.t | Account of Addr.t | Hash of Addr.t
  [@@deriving sexp, hash, compare]

  val is_generic : t -> bool

  val is_account : t -> bool

  val is_hash : t -> bool

  val height : ledger_depth:int -> t -> int

  val root_hash : t

  val last_direction : Addr.t -> Mina_stdlib.Direction.t

  val build_generic : Bigstring.t -> t

  val parse : ledger_depth:int -> Bigstring.t -> (t, unit) Result.t

  val prefix_bigstring : Unsigned.UInt8.t -> Bigstring.t -> Bigstring.t

  val to_path_exn : t -> Addr.t

  val serialize : ledger_depth:int -> t -> Bigstring.t

  val parent : t -> t

  val next : t -> t Option.t

  val prev : t -> t Option.t

  val sibling : t -> t

  val order_siblings : t -> 'a -> 'a -> 'a * 'a

  val merkle_path_dependencies_exn : t -> (t * Mina_stdlib.Direction.t) list

  include Comparable.S with type t := t
end

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

module type SYNCABLE = sig
  type root_hash

  type hash

  type account

  type addr

  type t

  type path

  val depth : t -> int

  val num_accounts : t -> int

  val merkle_path_at_addr_exn : t -> addr -> path

  val get_inner_hash_at_addr_exn : t -> addr -> hash

  val set_all_accounts_rooted_at_exn : t -> addr -> account list -> unit

  val set_batch_accounts : t -> (addr * account) list -> unit

  (** Get all of the accounts that are in a subtree of the underlying Merkle
    tree rooted at `address`. The accounts are ordered by their addresses. *)
  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list

  val merkle_root : t -> root_hash
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

    module Location : LOCATION
  end

  module type DATABASE = sig
    include Intf

    module Location_binable : Hashable.S_binable with type t := Location.t

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

    module Location : LOCATION

    include
      SYNCABLE
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

    (** iterate over all indexes and accounts, if the ledger is not known to be sound *)
    val iteri_untrusted : t -> f:(index -> account option -> unit) -> unit

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

    val set_batch :
      ?hash_cache:hash Addr.Map.t -> t -> (Location.t * account) list -> unit

    val get_at_index : t -> int -> account option

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

    (** Get all accounts on all masks of current ledger until reaching a 
        non-mask. Used to migrate root to an potential staged ledger for fork 
        config generation *)
    val all_accounts_on_masks : t -> account Location.Map.t
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

    module Location : LOCATION

    (** The type of the witness for a base ledger exposed here so that it can
   * be easily accessed from outside this module *)
    type witness

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

    val create : ?directory_name:string -> ?fresh:bool -> depth:int -> unit -> t

    (** create_checkpoint would create the checkpoint and open a db connection to that checkpoint *)
    val create_checkpoint : t -> directory_name:string -> unit -> t

    (** make_checkpoint would only create the checkpoint *)
    val make_checkpoint : t -> directory_name:string -> unit

    val with_ledger : depth:int -> f:(t -> 'a) -> 'a

    module For_tests : sig
      val gen_account_location :
        ledger_depth:int -> Location.t Quickcheck.Generator.t
    end
  end

  module Converting = struct
    open struct
      module type LEDGER_S = S
    end

    module type S = sig
      include LEDGER_S

      type primary_ledger

      type converting_ledger

      type converted_account

      (** Create a converting ledger based on two component ledgers. No migration is
      performed (use [of_ledgers_with_migration] if you need this) but all
      subsequent write operations on the converting merkle tree will be applied
      to both ledgers. *)
      val of_ledgers : primary_ledger -> converting_ledger -> t

      (** Create a converting ledger with an already-existing [Primary_ledger.t] and
      an empty [Converting_ledger.t] that will be initialized with the migrated
      account data. *)
      val of_ledgers_with_migration : primary_ledger -> converting_ledger -> t

      (** Retrieve the primary ledger backing the converting merkle tree *)
      val primary_ledger : t -> primary_ledger

      (** Retrieve the converting ledger backing the converting merkle tree *)
      val converting_ledger : t -> converting_ledger

      (** The input account conversion method, re-exposed for convenience *)
      val convert : account -> converted_account
    end

    module type Config = sig
      type t = { primary_directory : string; converting_directory : string }
      [@@deriving yojson]

      type create =
        | Temporary
            (** Create a converting ledger with databases in temporary directories *)
        | In_directories of t
            (** Create a converting ledger with databases in explicit directories *)

      (** Create a [checkpoint] config with the default converting directory
        name *)
      val with_primary : directory_name:string -> t

      (** Given a primary dir, returns the default converting_directory path associated with that primary dir *)
      val default_converting_directory_name : string -> string
    end

    module type WITH_DATABASE = sig
      include S

      module Config : Config

      val dbs_synced : primary_ledger -> converting_ledger -> bool

      (** Create a new converting merkle tree with the given configuration. If
      [In_directories] is given, existing databases will be opened and used to
      back the converting merkle tree. If the converting database does not exist
      in the directory, or exists but is empty, one will be created by migrating
      the primary database. Existing but incompatible converting databases (such
      as out-of-sync databases) will be deleted and re-migrated. *)
      val create :
           config:Config.create
        -> logger:Logger.t
        -> depth:int
        -> ?assert_synced:bool
        -> unit
        -> t

      (** Make checkpoints of the databases backing the converting merkle tree and
      create a new converting ledger based on those checkpoints *)
      val create_checkpoint : t -> config:Config.t -> unit -> t

      (** Make checkpoints of the databases backing the converting merkle tree *)
      val make_checkpoint : t -> config:Config.t -> unit
    end
  end
end

module Graphviz = struct
  module type S = sig
    type addr

    type ledger

    type t

    (* Visualize will enumerate through all edges of a subtree with a
       initial_address. It will then interpret all of the edges and nodes into an
       intermediate form that will be easy to write into a dot file *)
    val visualize : ledger -> initial_address:addr -> t

    (* Write will transform the intermediate form generate by visualize and save
       the results into a dot file *)
    val write : path:string -> name:string -> t -> unit Async.Deferred.t
  end

  module type I = sig
    include Inputs.Intf

    module Ledger :
      Ledger.S
        with module Addr = Location.Addr
         and module Location = Location
         and type account_id := Account_id.t
         and type account_id_set := Account_id.Set.t
         and type hash := Hash.t
         and type account := Account.t
  end
end
