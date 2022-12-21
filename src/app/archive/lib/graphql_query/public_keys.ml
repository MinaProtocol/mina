module Query =
[%graphql
{|
query query {
    public_keys {
        value @ppxCustom(module: "Graphql_lib.Serializing.Public_key_s")
    }
}
|}]
