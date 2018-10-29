open Core

module type Key = sig
  type t [@@deriving sexp, bin_io]

  val empty : t

  include Hashable.S_binable with type t := t
end

module type Balance = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account = sig
  type t [@@deriving bin_io, eq]

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
  type t

  val copy : t -> t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val set_batch : t -> key_data_pairs:(Bigstring.t * Bigstring.t) list -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database = sig
  type t

  val copy : t -> t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option

  val length : t -> int
end

module type Storage_locations = sig
  val key_value_db_dir : string

  val stack_db_file : string
end
