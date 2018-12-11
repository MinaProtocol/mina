open Core

module type Key = sig
  type t [@@deriving sexp, bin_io, eq]

  val empty : t

  include Hashable.S_binable with type t := t
end

module type Balance = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account = sig
  type t [@@deriving bin_io, eq, sexp]

  type key

  val public_key : t -> key

  val empty : t
end

module type Hash = sig
  type t [@@deriving bin_io, sexp]

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

  include
    Key_value_database.S
    with type t := t
     and type key := Bigstring.t
     and type value := Bigstring.t

  val get_uuid : t -> Uuid.t

  val set_batch : t -> key_data_pairs:(Bigstring.t * Bigstring.t) list -> unit

  val to_alist : t -> (Bigstring.t * Bigstring.t) list
  (* an association list, sorted by key *)
end

module type Storage_locations = sig
  val key_value_db_dir : string
end
