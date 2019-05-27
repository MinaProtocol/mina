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
