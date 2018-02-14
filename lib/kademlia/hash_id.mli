open Core_kernel

type t [@@deriving sexp, bin_io]

(* Throws if nonce is not exactly 14bytes *)
val create : nonce:Bigstring.t -> t

val random_nonce : unit -> Bigstring.t

val verify : t -> bool

val to_bits : t -> bool list
val of_bits : bool list -> t

