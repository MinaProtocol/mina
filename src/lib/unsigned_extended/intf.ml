open Core

type uint64 = Unsigned.uint64

type uint32 = Unsigned.uint32

module type S = sig
  type t [@@deriving bin_io, sexp, hash, compare, eq, yojson, version]

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
  (Signed :sig
           
           type t [@@deriving bin_io]
         end)
  (M :sig
      
      val to_signed : Unsigned.t -> Signed.t

      val of_signed : Signed.t -> Unsigned.t

      val length : int
    end)
  -> S with type t = Unsigned.t
