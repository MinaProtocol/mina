// Needed to get urql working from nodejs
%raw
"global.fetch = require(\"node-fetch\");";

let endpoint =
  Constants.graphqlHost ++ ":" ++ Constants.graphqlPort ++ "/graphql";

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

module Decoders = {
  let publicKey = pk => Js.Json.decodeString(pk) |> Belt.Option.getExn;
  let int64 = i =>
    Js.Json.decodeString(i) |> Belt.Option.getExn |> Int64.of_string;
};

module Encoders = {
  let publicKey = s => s |> Js.Json.string;
  let int64 = s => s |> Int64.to_string |> Js.Json.string;
};

let combinedErrorToString = (e: UrqlCombinedError.combinedError) => {
  switch (e) {
  | {networkError: Some(e)} =>
    let default = Js.String.make(e);
    let message = Belt.Option.getWithDefault(Js.Exn.message(e), default);
    "[Network: " ++ message ++ "]";
  | {graphqlErrors: Some(errors)} =>
    Array.to_list(errors)
    |> List.map(e => {
         let msg =
           Belt.Option.getWithDefault(
             Js.Nullable.toOption(UrqlCombinedError.messageGet(e)),
             "Unknown error",
           );
         "[GraphQL: " ++ msg ++ "]";
       })
    |> String.concat(", ")
  | _ => "[Unknown error]"
  };
};
