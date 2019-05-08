open Tc;
let createClient = uri => {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let httpLink =
    ApolloLinks.createHttpLink(~uri, ~fetch=Bindings.Fetch.fetch, ());
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());
};

module CreateQuery = (Config: ReasonApolloTypes.Config) => {
  module ReasonApolloInternal = ReasonApolloQuery.Make(Config);
  let query = instance => {
    Task.liftPromise(() =>
      instance##query({
        "query": ReasonApolloInternal.graphqlQueryAST,
        "variables": Js.Json.array([||]),
      })
    )
    |> Task.map(~f=v => ReasonApolloInternal.convertJsInputToReason(v));
  };
};
