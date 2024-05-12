module T = Nat.Make32 ()
module Wire_types = Mina_wire_types.Mina_numbers.Txn_version

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = sig
    include Nat.Intf.UInt32_A with type Stable.V1.t = A.V1.t
  end
end

module Make_str (_ : Wire_types.Concrete) = struct
  include T
end

include Wire_types.Make (Make_sig) (Make_str)

let equal_to_current ~current t = t = current

let older_than_current ~current t = t < current

let equal_to_current_checked ~current t = Checked.(t = current)

let older_than_current_checked ~current t = Checked.(t < current)
