let client = {
  let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
  let uri = "http://graphql.o1test.net/graphql";
  let codaLink = ApolloLinks.createHttpLink(~uri, ());
  ReasonApollo.createApolloClient(~link=codaLink, ~cache=inMemoryCache, ());
};

module Decoders = {
  let string = v =>
    switch (Js.Json.decodeString(v)) {
    | Some(s) => s
    | None => ""
    };

  let int64 = pk => {
    switch (Js.Json.decodeString(pk)) {
    | Some(s) => Int64.of_string(s)
    | None => Int64.zero
    };
  };

  let date = s => Js.Date.fromFloat(float_of_string(s));
};
