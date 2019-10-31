let client = {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let uri = "http://34.221.132.14:10900/graphql";
  let codaLink = ApolloLinks.createHttpLink(~uri, ());
  ReasonApollo.createApolloClient(~link=codaLink, ~cache=inMemoryCache, ());
};
