type t

val typ : t Ctypes.typ

val length : t -> int
val to_string : t -> string
val delete : t -> unit
val of_string_don't_delete : string -> t
