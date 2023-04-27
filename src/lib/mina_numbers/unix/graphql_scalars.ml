open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module GlobalSlotSinceGenesis =
    Make_scalar_using_to_string
      (Mina_numbers.Global_slot_since_genesis)
      (struct
        let name = "Globalslotsincegenesis"

        let doc = "globalslotsincegenesis"
      end)
      (Schema)

  module GlobalSlotSinceHardFork =
    Make_scalar_using_to_string
      (Mina_numbers.Global_slot_since_hard_fork)
      (struct
        let name = "Globalslotsincehardfork"

        let doc = "globalslotsincehardfork"
      end)
      (Schema)

  module AccountNonce =
    Make_scalar_using_to_string
      (Mina_numbers.Account_nonce)
      (struct
        let name = "AccountNonce"

        let doc = "account nonce"
      end)
      (Schema)

  module Length =
    Make_scalar_using_to_string
      (Mina_numbers.Length)
      (struct
        let name = "Length"

        let doc = "length"
      end)
      (Schema)
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "GlobalSlotSinceGenesis" =
      ( module Make_test
                 (GlobalSlotSinceGenesis)
                 (Mina_numbers.Global_slot_since_genesis) )

    let%test_module "GlobalSlotSinceHardFork" =
      ( module Make_test
                 (GlobalSlotSinceHardFork)
                 (Mina_numbers.Global_slot_since_hard_fork) )

    let%test_module "AccountNonce" =
      (module Make_test (AccountNonce) (Mina_numbers.Account_nonce))

    let%test_module "Length" = (module Make_test (Length) (Mina_numbers.Length))
  end )
