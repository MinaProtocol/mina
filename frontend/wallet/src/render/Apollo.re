open Tc;

let createClient = (~faker, ~coda) => {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let fakerLink =
    ApolloLinks.createHttpLink(~uri=faker, ~fetch=Bindings.Fetch.fetch, ());
  let codaLink =
    ApolloLinks.createHttpLink(~uri=coda, ~fetch=Bindings.Fetch.fetch, ());

  let link =
    ApolloLinks.split(
      operation => {
        let operation: {. "operationName": option(string)} =
          Obj.magic(operation);
        operation##operationName == Some("addWallet")
        ||
        operation##operationName == Some("getWallets");
      },
      codaLink,
      fakerLink,
    );

  ReasonApollo.createApolloClient(~link, ~cache=inMemoryCache, ());
};

let client =
  createClient(
    ~faker="http://localhost:8080/graphql",
    ~coda="http://localhost:49370/graphql",
  );

module Decoders = {
  let int64 = Int64.of_string;
  let optInt64 = Option.map(~f=Int64.of_string);
  let publicKey = PublicKey.ofStringExn;

  let date = Js.Date.fromString;
  let optDate = Option.map(~f=Js.Date.fromString);
};
