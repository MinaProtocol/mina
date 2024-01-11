let introspection_query_raw =
  {graphql|
query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
      types {
        ...FullType
      }
      directives {
        name
        description
        locations
        args {
          ...InputValue
        }
      }
    }
  }
  fragment FullType on __Type {
    kind
    name
    description
    fields(includeDeprecated: true) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }
  fragment InputValue on __InputValue {
    name
    description
    type { ...TypeRef }
    defaultValue
  }
  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                }
              }
            }
          }
        }
      }
    }
  }
|graphql}

let () =
  let introspection_query =
    match Graphql_parser.parse introspection_query_raw with
    | Ok res ->
        res
    | Error err ->
        failwith err
  in
  let fake_mina_lib = Obj.magic () in
  let res =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Graphql_async.Schema.execute Mina_graphql.schema fake_mina_lib
          introspection_query )
  in
  let response =
    match res with
    | Ok (`Response data) ->
        data
    | _ ->
        failwith "Unexpected response"
  in
  let pretty_string = Yojson.Basic.pretty_to_string response in
  Format.printf "%s@." pretty_string
