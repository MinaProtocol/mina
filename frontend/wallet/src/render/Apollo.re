open Tc;

let createClient = uri => {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let httpLink =
    ApolloLinks.createHttpLink(~uri, ~fetch=Bindings.Fetch.fetch, ());
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());
};

let faker = createClient("http://localhost:8080/graphql");

module Decoders = {
  let int64 = Int64.of_string;
  let optInt64 = Option.map(~f=Int64.of_string);
  let publicKey = PublicKey.ofStringExn;

  let date = Js.Date.fromString;
  let optDate = optionalDate =>
    Option.map(~f=Js.Date.fromString, optionalDate);
};
