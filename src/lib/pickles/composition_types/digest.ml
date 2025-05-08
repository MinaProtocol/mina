open Pickles_types
open Core_kernel
module Limbs = Nat.N4

module Constant = struct
  include Limb_vector.Constant.Make (Limbs)

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_4.Stable.V1.t
      [@@deriving compare, sexp, yojson, hash, equal]

      let to_latest = Fn.id
    end
  end]

  (* Force the typechecker to verify that these types are equal. *)
  let (_ : (t, Stable.Latest.t) Type_equal.t) = Type_equal.T

  let to_tick_field x = Backend.Tick.Field.of_bits (to_bits x)

  let to_tock_field x = Backend.Tock.Field.of_bits (to_bits x)

  let of_tick_field x = of_bits (Backend.Tick.Field.to_bits x)
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
  type t = Impl.Field.t

  let to_bits = Impl.Field.choose_preimage_var ~length:Impl.Field.size_in_bits

  module Unsafe = struct
    let to_bits_unboolean x =
      Impl.with_label __LOC__ (fun () ->
          let length = Impl.Field.size_in_bits in
          let res =
            Impl.exists
              (Impl.Typ.list Impl.Boolean.typ_unchecked ~length)
              ~compute:
                Impl.As_prover.(
                  fun () -> Impl.Field.Constant.unpack (read_var x))
          in
          Impl.Field.Assert.equal x (Impl.Field.project res) ;
          res )
  end

  let () = assert (Impl.Field.size_in_bits < 64 * Nat.to_int Limbs.n)

  module Constant = struct
    include Constant

    let to_bits x = List.take (to_bits x) Impl.Field.size_in_bits
  end

  let typ =
    Impl.Typ.transport Impl.Field.typ
      ~there:(Fn.compose Impl.Field.Constant.project Constant.to_bits)
      ~back:(Fn.compose Constant.of_bits Impl.Field.Constant.unpack)
end
