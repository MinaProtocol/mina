module Digit : sig
  type t =
    | H0
    | H1
    | H2
    | H3
    | H4
    | H5
    | H6
    | H7
    | H8
    | H9
    | H10
    | H11
    | H12
    | H13
    | H14
    | H15

  val of_char_exn : Core_kernel.Char.t -> t

  val to_int : t -> int
end

val hex_char_of_int_exn : int -> char

module Sequence_be : sig
  type t = Digit.t array

  val decode : ?pos:int -> string -> Digit.t Core_kernel.Array.t

  val to_bytes_like :
    init:(int -> f:(int -> Core_kernel.Char.t) -> 'a) -> t -> 'a

  val to_string : t -> string

  val to_bytes : t -> Core_kernel.Bytes.t

  val to_bigstring : t -> Core_kernel.Bigstring.t
end

val decode :
  ?pos:int -> init:(int -> f:(int -> Core_kernel.Char.t) -> 'a) -> string -> 'a

val encode : string -> string

module Safe : sig
  val to_hex : string -> string

  val of_hex : string -> string option
end
