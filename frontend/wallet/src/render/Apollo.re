let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let httpLink =
  ApolloLinks.createHttpLink(~uri="http://localhost:8080/graphql", ());
let client =
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());
