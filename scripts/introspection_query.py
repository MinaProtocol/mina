import argparse
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


def print_schema(port, uri, extra_headers):
    conn = http.client.HTTPConnection("localhost", port)
    headers = {"Content-type": "application/json; charset=uft",
               "Accept": "text/plain"}
    headers.update(extra_headers)

    json_body = {
      'query': introspection_query,
      'variables': None,
      'operationName': "IntrospectionQuery"
    }

    conn.request("POST", uri, body=json.dumps(json_body), headers=headers)
    response = conn.getresponse()
    data = response.read()
    conn.close()

    parsed = json.loads(data.decode('utf-8'))
    print(json.dumps(parsed, indent=2))


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
      '-p', '--port', default=8080, type=int,
      help='The port of the graphql server to run introspection_query')

    parser.add_argument(
      '--uri', default='/graphql', type=str,
      help='The path to communicate to the graphql server')

    parser.add_argument('--headers', nargs='*', default=[])

    args = parser.parse_args()
    headers = [key_value.split(':') for key_value in args.headers]
    print_schema(args.port, args.uri, headers)

if __name__ == "__main__":
    main()
