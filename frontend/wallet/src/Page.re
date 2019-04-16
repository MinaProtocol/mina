open Tc;

let component = ReasonReact.statelessComponent("Page");

let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let httpLink =
  ApolloLinks.createHttpLink(~uri="http://localhost:8080/graphql", ());
let instance =
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());

MainCommunication.listen();

[@react.component]
let make = (~message) => {
  let url = ReasonReact.Router.useUrl();

  let (modalView, settingsOrError) =
    switch (Route.parse(url.hash)) {
    | None =>
      Js.log2("Failed to parse route: ", url.hash);
      (None, `Error(`Json_parse_error));
    | Some({Route.path, settingsOrError}) =>
      Js.log3("Got path, settingsOrError: ", path, settingsOrError);
      (
        switch (path) {
        | Route.Path.Send => Some(<Send />)
        | DeleteWallet => Some(<Delete />)
        | Home => None
        },
        settingsOrError,
      );
    };

  let randomNum = Js.Math.random_int(0, 1000);

  let handleChangeName = () =>
    switch (settingsOrError) {
    | `Settings(settings) =>
      let task =
        SettingsRenderer.add(
          settings,
          ~key=PublicKey.ofStringExn(randomNum |> Js.Int.toString),
          ~name="Test Wallet",
        );
      Js.log("Add started");
      Task.attempt(task, ~f=res => Js.log2("Add complete", res));
    | _ => Js.log("There's an error")
    };

  let settingsInfo = {
    let question = " (did you create a settings.json file with {\"state\": {}} ?)";
    switch (settingsOrError) {
    | `Settings(_) => "Settings loaded successfully"
    | `Error(`Json_parse_error) =>
      "Settings failed to load with a json parse error" ++ question
    | `Error(`Decode_error(s)) =>
      "Settings failed to decode with " ++ s ++ question
    | `Error(`Error_reading_file(e)) =>
      "Settings failed to load with a js exception"
      ++ question
      ++ (Js.Exn.stack(e) |> Option.withDefault(~default=""))
    };
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
      <div
        className=Css.(
          style([
            display(`flex),
            flexDirection(`column),
            justifyContent(`spaceBetween),
            height(`percent(100.)),
          ])
        )>
        <div>
          <div
            className=Css.(style([display(`flex), flexDirection(`column)]))>
            <Header />
            <Body message={message ++ ";; " ++ settingsInfo} />
          </div>
          <button
            onClick={_e => Router.(navigate({path: Send, settingsOrError}))}>
            {ReasonReact.string("Send")}
          </button>
          <button
            onClick={_e =>
              Router.(navigate({path: DeleteWallet, settingsOrError}))
            }>
            {ReasonReact.string("Delete wallet")}
          </button>
          <button onClick={_e => handleChangeName()}>
            {ReasonReact.string(
               "Change name: " ++ Js.Int.toString(randomNum),
             )}
          </button>
        </div>
        <div>
          {switch (settingsOrError) {
           | `Settings(settings) =>
             <Footer
               stakingKey={PublicKey.ofStringExn("131243123")}
               settings
             />
           | `Error(_) => <span />
           }}
          <Modal settingsOrError view=modalView />
        </div>
      </div>
    </div>
  </ApolloShim.Provider>;
};
