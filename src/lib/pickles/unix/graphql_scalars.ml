open Graphql_basic_scalars

module VerificationKey =
  Make_scalar_using_base64
    (Pickles.Side_loaded.Verification_key)
    (struct
      let name = "VerificationKey"

      let doc = "verification key in Base64 format"
    end)

module VerificationKeyHash =
  Make_scalar_using_to_string
    (Pickles.Backend.Tick.Field)
    (struct
      let name = "VerificationKeyHash"

      let doc = "Hash of verification key"
    end)
