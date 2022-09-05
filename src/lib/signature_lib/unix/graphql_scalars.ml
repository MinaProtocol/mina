module PublicKey :
  Graphql_basic_scalars.Json_intf
    with type t = Signature_lib.Public_key.Compressed.t = struct
  type t = Signature_lib.Public_key.Compressed.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> Signature_lib.Public_key.of_base58_check_decompress_exn

  let serialize key =
    `String (Signature_lib.Public_key.Compressed.to_base58_check key)

  let typ () =
    Graphql_async.Schema.scalar "PublicKey"
      ~doc:"Base58Check-encoded public key string" ~coerce:serialize
end

let%test_module "PublicKey" =
  ( module Graphql_basic_scalars.Make_test
             (PublicKey)
             (Signature_lib.Public_key.Compressed) )
