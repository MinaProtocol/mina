open Core_kernel

type uint64 = Unsigned.uint64

type uint32 = Unsigned.uint32

module type S = sig
  type t [@@deriving sexp, hash, compare, eq, yojson]

  val length_in_bits : int

  include Hashable.S with type t := t

  include Unsigned.S with type t := t

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( >= ) : t -> t -> bool
end

module type F = functor
  (Unsigned : Unsigned.S)
  (M :sig
      
      val length : int
    end)
  -> S with type t = Unsigned.t
