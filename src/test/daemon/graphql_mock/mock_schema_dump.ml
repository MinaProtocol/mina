(** Introspect [Mock_schema.schema] and print the result as JSON to stdout.

    Mirrors [src/app/graphql_schema_dump/graphql_schema_dump.ml] exactly,
    but operates on the mock schema and uses [Obj.magic ()] for the
    context (introspection never invokes resolvers, so the context value
    is never dereferenced).

    Captured into [mock_schema.json] via the [(rule ...)] in the root
    [dune] file, with [(mode promote)] so the JSON is written back into
    the source tree. CI then runs [git diff --exit-code mock_schema.json]
    plus a subset comparison against [graphql_schema.json]. *)

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
  (* Introspection never invokes resolvers, so the context value is unused.
     Same trick as src/app/graphql_schema_dump/graphql_schema_dump.ml. *)
  let fake_ctx : Mina_graphql_mock.Mock_context.t = Obj.magic () in
  let res =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Graphql_async.Schema.execute Mina_graphql_mock.Mock_schema.schema
          fake_ctx introspection_query )
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
