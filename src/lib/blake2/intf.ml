open Core_kernel

module type S = sig
  val digest_size_in_bits : int

  val digest_size_in_bytes : int

  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, version, sexp, compare, hash]

      include Hashable.S with type t := t
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, hash]

  include Hashable.S with type t := t

  include Comparable.S with type t := t

  val bits_to_string : bool array -> string

  val string_to_bits : string -> bool array

  val to_raw_string : t -> string

  val digest_string : ?off:int -> ?len:int -> String.t -> t
end
