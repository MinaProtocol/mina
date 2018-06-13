open Core_kernel

module type S = sig
  type t [@@deriving bin_io, sexp, hash, compare, eq]

  include Hashable.S with type t := t

  include Unsigned.S with type t := t

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( >= ) : t -> t -> bool
end

module type F = functor (Unsigned :
  Unsigned.S) -> functor (Signed :sig
                                    
                                    type t [@@deriving bin_io]
end) -> functor (M :sig
                      
                      val to_signed : Unsigned.t -> Signed.t

                      val of_signed : Signed.t -> Unsigned.t

                      val length : int
end) -> S with type t = Unsigned.t

module Extend : F

module UInt64 : S with type t = Unsigned.UInt64.t

module UInt32 : S with type t = Unsigned.UInt32.t
