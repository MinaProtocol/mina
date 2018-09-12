type t
  [@@deriving sexp]

module Input_type : sig
  type t =
    | Text
    | Email
  val to_string : t -> string
end

val to_string : t -> string
val create : string -> string -> t

val class_ : string -> t

val href : string -> t

val src : string -> t

val type_ : Input_type.t -> t
val placeholder : string -> t
