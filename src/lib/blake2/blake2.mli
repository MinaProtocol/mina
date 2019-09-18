val digest_size_in_bits : int

val digest_size_in_bytes : int

module Stable : sig
  module V1 : sig
    type t [@@deriving bin_io, version]
  end

  module Latest = V1
end

type t = Stable.V1.t

include Digestif.S with type t := t and type kind = [`BLAKE2S]

val bits_to_string : bool array -> string

val string_to_bits : string -> bool array
