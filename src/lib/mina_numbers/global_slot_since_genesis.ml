(** Global slot implementation *)

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_numbers.Global_slot_since_genesis

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Nat.Intf.UInt32_A with type Stable.V1.t = A.V1.t
end

module T = Nat.Make32 ()

module Make_str (A : Wire_types.Concrete) : Make_sig(A).S = struct
  include T
end

include Wire_types.Make (Make_sig) (Make_str)
