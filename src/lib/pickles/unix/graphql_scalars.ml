open Graphql_basic_scalars

module VerificationKey =
  Make_scalar_using_base58_check
    (Pickles.Side_loaded.Verification_key)
    (struct
      let name = "VerificationKey"

      let doc = "verification key in Base58Check format"
    end)

module VerificationKeyHash =
  Make_scalar_using_to_string
    (Pickles.Backend.Tick.Field)
    (struct
      let name = "VerificationKeyHash"

      let doc = "Hash of verification key"
    end)

(* TESTS *)
module VerificationKey_gen = struct
  include Pickles.Side_loaded.Verification_key

  let gen =
    String_gen.gen
    |> Core_kernel.Quickcheck.Generator.map ~f:(fun name ->
           Pickles.Tag.create ~name |> of_compiled )
end

let%test_module "VerificationKey" =
  (module Make_test (VerificationKey) (VerificationKey_gen))

module VerificationKeyHash_gen = struct
  include Pickles.Backend.Tick.Field

  let gen =
    Core_kernel.Int.quickcheck_generator
    |> Core_kernel.Quickcheck.Generator.map ~f:Pasta_bindings.Fp.of_int
end

let%test_module "VerificationKeyHash" =
  (module Make_test (VerificationKeyHash) (VerificationKeyHash_gen))
