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
      <div
        style={ReactDOMRe.Style.make(
          ~border="8px solid #11161b",
          ~position="absolute",
          ~top="0",
          ~right="0",
          ~bottom="0",
          ~left="0",
          ~display="flex",
          ~flexDirection="column",
          (),
        )}>
        <Header />
        <Body message />
      </div>
    </ReasonApollo.Provider>,
};
