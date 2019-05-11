let createClient = uri => {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let httpLink =
    ApolloLinks.createHttpLink(~uri, ~fetch=Bindings.Fetch.fetch, ());
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());
};

let faker = createClient("http://localhost:8080/graphql");
