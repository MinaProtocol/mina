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

  val public_key_of_account : t -> key

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

  val copy : t -> t

  val create : directory:string -> t

  val get_uuid : t -> Uuid.t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val set_batch : t -> key_data_pairs:(Bigstring.t * Bigstring.t) list -> unit

  val delete : t -> key:Bigstring.t -> unit

  val to_alist : t -> (Bigstring.t * Bigstring.t) list
end

module type Storage_locations = sig
  val key_value_db_dir : string
end
