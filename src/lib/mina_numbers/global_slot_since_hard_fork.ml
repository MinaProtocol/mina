(** Global slot (since hard fork) implementation *)

open Core_kernel

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_numbers.Global_slot_since_hard_fork

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
        type t = Wire_types.global_slot = Since_hard_fork of T.Stable.V1.t
        [@@unboxed] [@@deriving hash, compare, equal]

        let to_latest = Fn.id

        let sexp_of_t (Since_hard_fork u32) = Sexp.Atom (T.to_string u32)

        let t_of_sexp = function
          | Sexp.Atom i ->
              Since_hard_fork (T.of_string i)
          | _ ->
              failwith "Global_slot.of_sexp: Expected Atom"

        let to_yojson (Since_hard_fork u32) = `String (T.to_string u32)

        let of_yojson = function
          | `String i ->
              Ok (Since_hard_fork (T.of_string i))
          | _ ->
              Error "Global_slot.of_yojson: Expected `String"
      end
    end]

    module T = T

    let sexp_of_t = Stable.Latest.sexp_of_t

    let t_of_sexp = Stable.Latest.t_of_sexp

    let to_yojson = Stable.Latest.to_yojson

    let of_yojson = Stable.Latest.of_yojson

    let to_uint32 (Since_hard_fork u32) : uint32 = u32

    let of_uint32 u32 : t = Since_hard_fork u32
  end

  include M
  include Global_slot.Make (M)
end

include Wire_types.Make (Make_sig) (Make_str)
