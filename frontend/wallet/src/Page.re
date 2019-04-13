let component = ReasonReact.statelessComponent("Page");

let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let httpLink =
  ApolloLinks.createHttpLink(~uri="http://localhost:8080/graphql", ());
let instance =
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());

Router.listenToMain();

[@react.component]
let make = (~message) => {
  let url = ReasonReact.Router.useUrl();

  let modalView =
    switch (Route.parse(url.hash)) {
    | Some(Route.Send) => Some(<Send />)
    | Some(DeleteWallet) => Some(<Delete />)
    | Some(Home) => None
    | None =>
      Js.log2("Failed to parse route: ", url.hash);
      None;
    };

  <ApolloShim.Provider client=instance>
    <div
      style={ReactDOMRe.Style.make(
        ~border="8px solid #11161b",
        ~position="absolute",
        ~top="0",
        ~right="0",
        ~bottom="0",
        ~left="0",
        (),
      )}>
      <div className=Css.(style([display(`flex), flexDirection(`column)]))>
        <Header />
        <Body message />
      </div>
      <button onClick={_e => Router.(navigate(Send))}>
        {ReasonReact.string("Send")}
      </button>
      <button onClick={_e => Router.(navigate(DeleteWallet))}>
        {ReasonReact.string("Delete wallet")}
      </button>
      <Modal view=modalView />
    </div>
  </ApolloShim.Provider>;
};
