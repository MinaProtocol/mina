type t

val typ : t Ctypes.typ

val length : t -> int

val to_string : t -> string

val to_char_pointer : t -> char Ctypes.ptr

val delete : t -> unit

val of_string_don't_delete : string -> t

val of_char_pointer_don't_delete : char Ctypes.ptr -> int -> t

val to_bigstring : t -> Core.Bigstring.t
