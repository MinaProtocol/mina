(** Global slot (since genesis) implementation *)

open Core_kernel

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_numbers.Global_slot_since_genesis

type uint32 = Unsigned.uint32

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = sig
    include
      Global_slot_intf.S
        with type Stable.V1.t = A.V1.t
         and type global_slot_span = Global_slot_span.t
         and type Checked.global_slot_span_checked = Global_slot_span.Checked.t
  end
end

module T = Nat.Make32 ()

module Make_str (_ : Wire_types.Concrete) = struct
  module M = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Wire_types.global_slot = Since_genesis of T.Stable.V1.t
        [@@unboxed] [@@deriving hash, sexp, compare, equal, yojson]

        let to_latest = Fn.id
      end
    end]

    module T = T

    let to_uint32 (Since_genesis u32) : uint32 = u32

    let of_uint32 u32 : t = Since_genesis u32
  end

  include M
  include Global_slot.Make (M)
end

include Wire_types.Make (Make_sig) (Make_str)
