module T = Nat.Make32 ()

module Wire_types = Mina_wire_types.Mina_numbers.Index

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = sig
    include Nat.Intf.UInt32_A with type Stable.V1.t = A.V1.t
  end
end

module Make_str (_ : Wire_types.Concrete) = struct
  include T

  let to_bits = Bits.to_bits

  let of_bits = Bits.of_bits
end

include Wire_types.Make (Make_sig) (Make_str)
