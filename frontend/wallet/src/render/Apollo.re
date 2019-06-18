open Tc;

type retryOptions;

[@bs.module "apollo-link-retry"] [@bs.new]
external createRetryLink: retryOptions => ReasonApolloTypes.apolloLink =
  "RetryLink";

let client = {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();

  let uri = "http://localhost:49370/graphql";
  let codaLink =
    ApolloLinks.createHttpLink(~uri, ~fetch=Bindings.Fetch.fetch, ());

  let retryOptions: retryOptions = [%bs.raw
    {|
      {delay: {
        initial: 300,
        max: 500,
        jitter: false
      },
      attempts: {
        max: 60,
      }}
    |}
  ];
  let retry = createRetryLink(retryOptions);

  let retryLink = ApolloLinks.from([|retry, codaLink|]);

  ReasonApollo.createApolloClient(~link=retryLink, ~cache=inMemoryCache, ());
};

module Decoders = {
  let int64 = Int64.of_string;
  let optInt64 = Option.map(~f=Int64.of_string);
  let publicKey = PublicKey.ofStringExn;

  let date = Js.Date.fromString;
  let optDate = Option.map(~f=Js.Date.fromString);
};
