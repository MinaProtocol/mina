open Graphql_basic_scalars

module Slot_scalar =
  Make_scalar_using_to_string
    (Slot)
    (struct
      let name = "Slot"

      let doc = "slot"
    end)

module Epoch_scalar =
  Make_scalar_using_to_string
    (Epoch)
    (struct
      let name = "Epoch"

      let doc = "epoch"
    end)

(* TESTS *)
module Slot_gen = struct
  include Slot

  let gen =
    Core_kernel.Quickcheck.Generator.map ~f:Slot.of_uint32
      (Constants.for_unit_tests |> Lazy.force |> gen)
end

let%test_module "Epoch" = (module Make_test (Epoch_scalar) (Epoch))

let%test_module "Slot" = (module Make_test (Slot_scalar) (Slot_gen))

module Slot = Slot_scalar
module Epoch = Epoch_scalar

module VrfScalar =
  Make_scalar_using_to_string
    (Consensus_vrf.Scalar)
    (struct
      let name = "VrfScalar"

      let doc = "consensus vrf scalar"
    end)

module VrfScalar_gen = struct
  include Snark_params.Tick.Inner_curve.Scalar
end

let%test_module "VrfScalar" = (module Make_test (VrfScalar) (VrfScalar_gen))

module VrfOutputTruncated =
  Make_scalar_using_base58_check
    (Consensus_vrf.Output.Truncated)
    (struct
      let name = "VrfOutputTruncated"

      let doc = "truncated vrf output"
    end)

module VrfOutputTruncated_gen = struct
  include Consensus_vrf.Output.Truncated

  let gen = Core_kernel.Quickcheck.Generator.return dummy
end

let%test_module "VrfOutputTruncated" =
  (module Make_test (VrfOutputTruncated) (VrfOutputTruncated_gen))

module BodyReference = struct
  open Body_reference

  type nonrec t = t

  let parse json = Yojson.Basic.Util.to_string json |> of_hex_exn

  let serialize x = `String (to_hex x)

  let typ () =
    Graphql_async.Schema.scalar "BodyReference"
      ~doc:
        "A reference to how the block header refers to the body of the block \
         as a hex-encoded string"
      ~coerce:serialize
end

(*
TODO: add tests for this type
module BodyReference_gen = struct
 include Body_reference
end
 *)

(* let%test_module "BodyReference" = (module Make_test (BodyReference) (BodyReference_gen)) *)
