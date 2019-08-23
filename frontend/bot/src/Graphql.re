// Needed to get urql working from nodejs
%raw
"global.fetch = require(\"node-fetch\");";

let endpoint =
  Constants.graphqlHost ++ ":" ++ string_of_int(Constants.graphqlPort) ++ "/graphql";

[@bs.module]
external websocketImpl: SubscriptionsTransportWS.websocketImpl =
  "isomorphic-ws";

let client = {
  let subscriptionClient =
    SubscriptionsTransportWS.subscriptionClient(
      ~url="ws://" ++ endpoint,
      ~subscriptionClientConfig=
        SubscriptionsTransportWS.subscriptionClientConfig(),
      ~websocketImpl,
    );

  let forwardSubscription = operation =>
    subscriptionClient##request(operation);

  let subscriptionExchangeOpts =
    ReasonUrql.Exchanges.subscriptionExchangeOpts(~forwardSubscription);

  let subscriptionExchange =
    ReasonUrql.Exchanges.subscriptionExchange(subscriptionExchangeOpts);

  Logger.log("Graphql", `Info, "Connecting to %s", endpoint);

  ReasonUrql.Client.make(
    ~url="http://" ++ endpoint,
    ~exchanges=
      Array.append(
        ReasonUrql.Exchanges.defaultExchanges,
        [|subscriptionExchange|],
      ),
    (),
  );
};

type response('a) =
  | NotFound
  | Data('a)
  | Error(string);

type err;

[@bs.deriving abstract]
type responseJs = {
  data: Js.Nullable.t(Js.Json.t),
  [@bs.optional]
  error: err,
};

let processResponse = (parse, response) => {
  let data = response->dataGet->Js.Nullable.toOption->Belt.Option.map(parse);
  let error = response->errorGet;

  switch (data, error) {
  | (Some(data), _) => Data(data)
  | (_, Some(error)) => Error(Js.String.make(error))
  | (None, None) => NotFound
  };
};

let executeQuery = gqlReq => {
  let req =
    ReasonUrql.Request.createRequest(
      ~query=gqlReq##query,
      ~variables=gqlReq##variables,
      (),
    );
  let parse = processResponse(gqlReq##parse);
  ReasonUrql.Client.executeQuery(~client, ~query=req, ())
  |> Wonka.map((. a) => parse(a));
};

let executeMutation = gqlReq => {
  let req =
    ReasonUrql.Request.createRequest(
      ~query=gqlReq##query,
      ~variables=gqlReq##variables,
      (),
    );
  let parse = processResponse(gqlReq##parse);
  ReasonUrql.Client.executeMutation(~client, ~mutation=req, ())
  |> Wonka.map((. a) => parse(a));
};

let executeSubscription = gqlReq => {
  let req =
    ReasonUrql.Request.createRequest(
      ~query=gqlReq##query,
      ~variables=gqlReq##variables,
      (),
    );
  let parse = processResponse(gqlReq##parse);
  ReasonUrql.Client.executeSubscription(~client, ~subscription=req, ())
  |> Wonka.map((. a) => parse(a));
};

module Decoders = {
  let publicKey = pk => Js.Json.decodeString(pk) |> Belt.Option.getExn;
  let int64 = i =>
    Js.Json.decodeString(i) |> Belt.Option.getExn |> Int64.of_string;
};

module Encoders = {
  let publicKey = s => s |> Js.Json.string;
  let int64 = s => s |> Int64.to_string |> Js.Json.string;
};
