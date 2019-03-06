let component = ReasonReact.statelessComponent("Page");

let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let httpLink =
  ApolloLinks.createHttpLink(~uri="http://localhost:8080/graphql", ());
let instance =
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());

let make = (~message, _children) => {
  ...component,
  render: _self =>
    <ReasonApollo.Provider client=instance>
      <Header />
      <Body message />
    </ReasonApollo.Provider>,
};
