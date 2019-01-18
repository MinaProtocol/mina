open Rocks_options

type bigarray = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

module type ITERATOR = sig
  module ReadOptions : module type of ReadOptions

  exception InvalidIterator

  type db
  type t

  val get_pointer : t -> unit Ctypes.ptr

  val create : ?opts:ReadOptions.t -> db -> t
  val with_t : ?opts:ReadOptions.t -> db -> f:(t -> 'a) -> 'a

  val is_valid : t -> bool

  val seek_to_first : t -> unit
  val seek_to_last : t -> unit

  val seek : ?pos:int -> ?len:int -> t -> bigarray -> unit
  val seek_string : ?pos:int -> ?len:int -> t -> string -> unit

  val next : t -> unit
  val prev : t -> unit

  val get_key_string : t -> string

  (** returned buffer is only valid as long as [t] is not modified *)
  val get_key : t -> bigarray

  val get_value_string : t -> string

  (** returned buffer is only valid as long as [t] is not modified *)
  val get_value : t -> bigarray

  val get_error : t -> string option
end

module type TRANSACTION = sig
  type t
  type db
  type iter
  module ReadOptions : module type of ReadOptions
  module WriteOptions : module type of WriteOptions
  module TransactionOptions : module type of TransactionOptions
  module Snapshot : module type of Snapshot

  val txnbegin : ?wopts:WriteOptions.t ->
                 ?txnopts:TransactionOptions.t -> db -> t
  val txnbegin_no_gc : ?wopts:WriteOptions.t ->
                       ?txnopts:TransactionOptions.t -> db -> t
  val commit : t -> unit
  val rollback : t -> unit
  val destroy : t -> unit
  val with_t : db -> (t -> unit) -> unit

  val get : ?pos:int -> ?len:int -> ?opts:ReadOptions.t -> t -> bigarray -> bigarray option
  val get_string : ?pos:int -> ?len:int -> ?opts:ReadOptions.t -> t -> string -> string option

  val put : ?key_pos:int -> ?key_len:int -> ?value_pos:int -> ?value_len:int -> ?opts:WriteOptions.t -> t -> bigarray -> bigarray -> unit
  val put_string : ?key_pos:int -> ?key_len:int -> ?value_pos:int -> ?value_len:int -> ?opts:WriteOptions.t -> t -> string -> string -> unit

  val delete : ?pos:int -> ?len:int -> ?opts:WriteOptions.t -> t -> bigarray -> unit
  val delete_string : ?pos:int -> ?len:int -> ?opts:WriteOptions.t -> t -> string -> unit

  val get_snapshot : t -> Snapshot.t
  val free_snapshot : Snapshot.t -> unit

  val create_iterator: ?opts:ReadOptions.t -> t -> iter
  val with_iterator: ?opts:ReadOptions.t -> t -> f:(iter -> 'a) -> 'a
end

module type ROCKS = sig
  module Options : module type of Options
  module ReadOptions : module type of ReadOptions
  module WriteOptions : module type of WriteOptions
  module FlushOptions : module type of FlushOptions
  module Cache : module type of Cache
  module BlockBasedTableOptions : module type of BlockBasedTableOptions
  module Snapshot : module type of Snapshot
  module TransactionDbOptions : module type of TransactionDbOptions

  type t
  type batch

  val get_pointer : t -> unit Ctypes.ptr

  val open_db : ?opts:Options.t -> string -> t
  val open_db_for_read_only : ?opts:Options.t -> string -> bool -> t
  val open_transactiondb : ?opts:Options.t -> ?txnopts:TransactionDbOptions.t -> string -> t
  val with_db : ?opts:Options.t -> string -> f:(t -> 'a) -> 'a
  val close : t -> unit

  val get : ?pos:int -> ?len:int -> ?opts:ReadOptions.t -> t -> bigarray -> bigarray option
  val get_string : ?pos:int -> ?len:int -> ?opts:ReadOptions.t -> t -> string -> string option

  val put : ?key_pos:int -> ?key_len:int -> ?value_pos:int -> ?value_len:int -> ?opts:WriteOptions.t -> t -> bigarray -> bigarray -> unit
  val put_string : ?key_pos:int -> ?key_len:int -> ?value_pos:int -> ?value_len:int -> ?opts:WriteOptions.t -> t -> string -> string -> unit

  val delete : ?pos:int -> ?len:int -> ?opts:WriteOptions.t -> t -> bigarray -> unit
  val delete_string : ?pos:int -> ?len:int -> ?opts:WriteOptions.t -> t -> string -> unit

  val write : ?opts:WriteOptions.t -> t -> batch -> unit

  val flush : ?opts:FlushOptions.t -> t -> unit

  val create_snapshot : t -> Snapshot.t
  val release_snapshot : t -> Snapshot.t -> unit

  val checkpoint_create : t -> string -> int -> unit
  val property_value : t -> string -> string option
end
