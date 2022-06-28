module Wire_types = Mina_wire_types.Mina_numbers.Global_slot

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Nat.Intf.UInt32_A with type Stable.V1.t = A.t
end

module T = Nat.Make32 ()

module Make_str (_ : Wire_types.Concrete) = struct
  include T
end

include Wire_types.Make (Make_sig) (Make_str)
