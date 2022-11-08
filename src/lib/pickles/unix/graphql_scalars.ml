open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module VerificationKey =
    Make_scalar_using_base64
      (Pickles.Side_loaded.Verification_key)
      (struct
        let name = "VerificationKey"

        let doc = "verification key in Base64 format"
      end)
      (Schema)

  module VerificationKeyHash =
    Make_scalar_using_to_string
      (Pickles.Backend.Tick.Field)
      (struct
        let name = "VerificationKeyHash"

        let doc = "Hash of verification key"
      end)
      (Schema)
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "VerificationKey" =
      ( module struct
        module VerificationKey_gen = struct
          include Pickles.Side_loaded.Verification_key

          let gen = Quickcheck.Generator.return dummy
        end

        include Make_test (VerificationKey) (VerificationKey_gen)
      end )

    let%test_module "VerificationKeyHash" =
      ( module struct
        module VerificationKeyHash_gen = struct
          include Pickles.Backend.Tick.Field

          let gen =
            Int.quickcheck_generator
            |> Quickcheck.Generator.map ~f:Pasta_bindings.Fp.of_int
        end

        include Make_test (VerificationKeyHash) (VerificationKeyHash_gen)
      end )
  end )
