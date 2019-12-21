open Tc;

type retryOptions;

[@bs.module "apollo-link-retry"] [@bs.new]
external createRetryLink: retryOptions => ReasonApolloTypes.apolloLink =
  "RetryLink";

let client = {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();

  let httpUri = "http://localhost:3085/graphql";
  let httpLink =
    ApolloLinks.createHttpLink(~uri=httpUri, ~fetch=Bindings.Fetch.fetch, ());

  let retryOptions: retryOptions = [%bs.raw
    {|
      {delay: {
        initial: 300,
        max: 2000,
        jitter: false
      },
      attempts: {
        max: 120,
      }}
    |}
  ];
  let retry = createRetryLink(retryOptions);

  let retryLink = ApolloLinks.from([|retry, httpLink|]);

  let wsUri = "ws://localhost:3085/graphql";
  let wsLink = ApolloLinks.webSocketLink(~uri=wsUri, ~reconnect=true, ());

  let combinedLink =
    ApolloLinks.split(
      operation => {
        let operationDefinition =
          ApolloUtilities.getMainDefinition(operation##query);
        operationDefinition##kind == "OperationDefinition"
        &&
        operationDefinition##operation == "subscription";
      },
      wsLink,
      retryLink,
    );

  ReasonApollo.createApolloClient(
    ~link=combinedLink,
    ~cache=inMemoryCache,
    (),
  );
};

module Decoders = {
  [@bs.val] [@bs.scope "window"] external isFaker: bool = "";

  let int64 = pk => {
    let s = Option.getExn(Js.Json.decodeString(pk));
    // hack for supporting faker
    if (s == "<UInt64>" && isFaker) {
      Int64.of_int(100);
    } else {
      Int64.of_string(s);
    };
  };

  let optInt64 = Option.map(~f=int64);

  let publicKey = pk => {
    let s = Js.Json.decodeString(pk) |> Option.getExn;

    // hack for supporting faker
    if (s == "<PublicKey>" && isFaker) {
      let values = [
        "Co9TeE1xZduCMtisEo9wadZ81g9bBPGgVKdQUrVZ2Z",
        "5RSJVkduNzMensh2SS12GRy8oQpfxR9oUDr7ETvu1b",
        "2A3Kkh68yoXAkEgAK1M52qYysJzUga6GxLrfjdv2ds",
      ];
      PublicKey.ofStringExn(
        Option.withDefault(
          ~default="",
          List.getAt(~index=Random.int(3), values),
        ),
      );
    } else {
      PublicKey.ofStringExn(s);
    };
  };

  let date = s =>
    // hack for supporting faker
    if (s == "string" && isFaker) {
      Js.Date.fromFloat(Js.Date.now());
    } else {
      Js.Date.fromFloat(float_of_string(s));
    };

  let optDate = Option.map(~f=date);
};

module Encoders = {
  let publicKey = s => s |> PublicKey.toString |> Js.Json.string;
  let int64 = s => s |> Int64.to_string |> Js.Json.string;
};
