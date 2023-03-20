open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module PublicKey :
    Json_intf with type t = Signature_lib.Public_key.Compressed.t = struct
    type t = Signature_lib.Public_key.Compressed.t

    let parse json =
      Yojson.Basic.Util.to_string json
      |> Signature_lib.Public_key.of_base58_check_decompress_exn

    let serialize key =
      `String (Signature_lib.Public_key.Compressed.to_base58_check key)

    let typ () =
      Schema.scalar "PublicKey" ~doc:"Base58Check-encoded public key string"
        ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "PublicKey" =
      (module Make_test (PublicKey) (Signature_lib.Public_key.Compressed))
  end )
