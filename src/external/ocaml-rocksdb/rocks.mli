exception OperationOnInvalidObject

type bigarray = Rocks_intf.bigarray

module Views : sig
  val bool_to_int : bool Ctypes.typ

  val bool_to_uchar : bool Ctypes.typ

  val int_to_size_t : int Ctypes.typ
end

module WriteBatch : sig
  include Rocks_common.S

  val clear : t -> unit

  val count : t -> int

  val put :
       ?key_pos:int
    -> ?key_len:int
    -> ?value_pos:int
    -> ?value_len:int
    -> t
    -> bigarray
    -> bigarray
    -> unit

  val put_string :
       ?key_pos:int
    -> ?key_len:int
    -> ?value_pos:int
    -> ?value_len:int
    -> t
    -> string
    -> string
    -> unit

  val delete : ?pos:int -> ?len:int -> t -> bigarray -> unit

  val delete_string : ?pos:int -> ?len:int -> t -> string -> unit
end

module Version : sig
  val major : int

  val minor : int

  val patch : int

  val git_revision : string

  val summary : int * int * int * string
end

include Rocks_intf.ROCKS with type batch := WriteBatch.t

module Iterator : Rocks_intf.ITERATOR with type db := t

module Transaction :
  Rocks_intf.TRANSACTION with type db := t and type iter := Iterator.t
