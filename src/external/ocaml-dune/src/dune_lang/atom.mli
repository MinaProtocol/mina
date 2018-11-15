type t = private A of string [@@unboxed]

val is_valid_dune : string -> bool
val is_valid : t -> Syntax.t -> bool

val of_string : string -> t
val to_string : t -> string

val print : t -> Syntax.t -> string

val of_int : int -> t
val of_float : float -> t
val of_bool : bool -> t
val of_int64 : Int64.t -> t
val of_digest : Digest.t -> t
