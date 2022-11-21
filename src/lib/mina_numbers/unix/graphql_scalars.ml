open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module GlobalSlot =
    Make_scalar_using_to_string
      (Mina_numbers.Global_slot)
      (struct
        let name = "Globalslot"

        let doc = "globalslot"
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

    let%test_module "GlobalSlot" =
      (module Make_test (GlobalSlot) (Mina_numbers.Global_slot))

    let%test_module "AccountNonce" =
      (module Make_test (AccountNonce) (Mina_numbers.Account_nonce))

    let%test_module "Length" = (module Make_test (Length) (Mina_numbers.Length))
  end )
