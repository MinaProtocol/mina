let message = __MODULE__;

module Kind = {
  type t =
    | Query
    | Mutation;
  // | Subscription;
};

module Typ = {
  type t('a) =
    | ResultString: t(Tc.Result.t(string, string));

  let if_eq =
      (
        type a,
        type b,
        ta: t(a),
        tb: t(b),
        v: b,
        ~is_equal: a => unit,
        ~not_equal as _: b => unit,
      ) => {
    switch (ta, tb) {
    | (ResultString, ResultString) => is_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

type definition = {. "operation": string};
type query = {. "definitions": array(definition)};

type apolloOperation = {
  .
  "operationName": string,
  "query": query,
  "variables": Js.Json.t,
};

type apolloMutation = {
  .
  "operationName": string,
  "mutation": query,
  "variables": Js.Json.t,
};

let mutationOfOperation = operation => {
  "operationName": operation##operationName,
  "mutation": operation##query,
  "variables": operation##variables,
};

type mainToRendererMessages = [
  | `Pipe_graphql_response(
      CallTable.Ident.Encode.t,
      Tc.Result.t(string, string),
    )
];

type rendererToMainMessages = [
  | `Pipe_graphql_request(CallTable.Ident.Encode.t, (Kind.t, string))
];
