open Core_kernel

module Digest = struct
  type t = Bigstring.t [@@deriving bin_io]

  module Snarkable (Impl : Snark_intf.S) =
    Bits.Make0(Impl)(struct
      let bit_length = 2 * Impl.Field.size_in_bits
      let bits_per_element = Impl.Field.size_in_bits
    end)
end

module State = struct
  type t = Todo

  let create = failwith "TODO"

  let update = failwith "TODO"

  let digest = failwith "TODO"
end
