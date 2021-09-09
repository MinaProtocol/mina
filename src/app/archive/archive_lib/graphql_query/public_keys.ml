open Signature_lib

module Query =
[%graphql
{|
query query {
    public_keys {
        value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
    }
}
|}]
