open Core_kernel

type uint64 = Unsigned.uint64

module type S = sig
  type t [@@deriving bin_io, sexp, hash, compare, eq]

  val length_in_bits : int

  include Hashable.S with type t := t

  include Unsigned.S with type t := t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

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

      val to_uint64 : Unsigned.t -> uint64

      val of_uint64 : uint64 -> Unsigned.t

      val length : int
    end)
  -> S with type t = Unsigned.t

module Extend : F

module UInt64 : S with type t = Unsigned.UInt64.t

module UInt32 : S with type t = Unsigned.UInt32.t
