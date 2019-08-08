import http.client
import json

# This introspection query is the typical one, taken from graphql_ppx
# copied into a python script to avoid adding a nodejs dep to our dune build
introspection_query = """
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
  }"""

conn = http.client.HTTPConnection("localhost", 8080)
headers = {"Content-type": "application/json","Accept": "text/plain"}
conn.request("POST", "/graphql", body="{query: \"%s\"}" % introspection_query, headers=headers)
response = conn.getresponse()
data = response.read()
conn.close()

parsed = json.loads(data)
print(json.dumps(parsed, indent=2))
