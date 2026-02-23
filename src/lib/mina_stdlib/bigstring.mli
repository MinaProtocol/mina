[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Core_kernel.Bigstring.Stable.V1.t [@@deriving sexp, compare]

    include Binable.S with type t := t

    val hash_fold_t : Hash.state -> t -> Hash.state

    val hash : t -> Hash.hash_value
  end
end]

include Hashable.S with type t := t

val get : t -> int -> char

val length : t -> int

val create : ?max_mem_waiting_gc:Core_kernel__Byte_units0.t -> int -> t

val to_string : ?pos:int -> ?len:int -> t -> string

val set : t -> int -> char -> unit

val blit : (t, t) Blit.blit

val sub : (t, t) Blit.sub
