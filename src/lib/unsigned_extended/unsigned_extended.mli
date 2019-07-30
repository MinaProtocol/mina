open Intf

type nonrec uint64 = uint64

type nonrec uint32 = uint32

module type S = S

module Extend : F

module UInt64 : sig
  include S with type t = Unsigned.UInt64.t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
end

module UInt32 : sig
  include S with type t = Unsigned.UInt32.t

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end
