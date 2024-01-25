open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module Slot_scalar =
    Make_scalar_using_to_string
      (Slot)
      (struct
        let name = "Slot"

        let doc = "slot"
      end)
      (Schema)

  module Epoch_scalar =
    Make_scalar_using_to_string
      (Epoch)
      (struct
        let name = "Epoch"

        let doc = "epoch"
      end)
      (Schema)

  module VrfScalar =
    Make_scalar_using_to_string
      (Consensus_vrf.Scalar)
      (struct
        let name = "VrfScalar"

        let doc = "consensus vrf scalar"
      end)
      (Schema)

  module VrfOutputTruncated =
    Make_scalar_using_base58_check
      (Consensus_vrf.Output.Truncated)
      (struct
        let name = "VrfOutputTruncated"

        let doc = "truncated vrf output"
      end)
      (Schema)

  module BodyReference : Json_intf with type t = Body_reference.t = struct
    open Body_reference

    type nonrec t = t

    let parse json = Yojson.Basic.Util.to_string json |> of_hex_exn

    let serialize x = `String (to_hex x)

    let typ () =
      Schema.scalar "BodyReference"
        ~doc:
          "A reference to how the block header refers to the body of the block \
           as a hex-encoded string"
        ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "Epoch" = (module Make_test (Epoch_scalar) (Epoch))

    let%test_module "Slot" =
      ( module struct
        module Slot_gen = struct
          include Slot

          let gen =
            Core_kernel.Quickcheck.Generator.map ~f:Slot.of_uint32
              (Constants.for_unit_tests |> Lazy.force |> gen)
        end

        include Make_test (Slot_scalar) (Slot_gen)
      end )

    let%test_module "VrfScalar" =
      ( module struct
        module VrfScalar_gen = struct
          include Snark_params.Tick.Inner_curve.Scalar
        end

        include Make_test (VrfScalar) (VrfScalar_gen)
      end )

    let%test_module "VrfOutputTruncated" =
      ( module struct
        module VrfOutputTruncated_gen = struct
          include Consensus_vrf.Output.Truncated

          let gen = Core_kernel.Quickcheck.Generator.return dummy
        end

        include Make_test (VrfOutputTruncated) (VrfOutputTruncated_gen)
      end )

    let%test_module "BodyReference" =
      ( module struct
        module BodyReference_gen = struct
          include Body_reference

          let gen = Blake2.gen
        end

        include Make_test (BodyReference) (BodyReference_gen)
      end )
  end )

module Slot = Slot_scalar
module Epoch = Epoch_scalar
