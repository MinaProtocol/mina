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
