open Graphql_basic_scalars.Utils

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
module For_tests_only = Make (Test_schema)
