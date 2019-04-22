open Tc;

let component = ReasonReact.statelessComponent("Page");

let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let httpLink =
  ApolloLinks.createHttpLink(~uri="http://localhost:8080/graphql", ());
let instance =
  ReasonApollo.createApolloClient(~link=httpLink, ~cache=inMemoryCache, ());

/// The semantics are as follows:
///
/// 1. Path is always aquired from a URL.
/// 2. The initial DeepLink's settingsOrError via the url seeds the
///    settingsOrError state.
/// 3. Afterwards, changes to settingsOrError are captured entirely via
///    responses to change messages sent from the GUI frontend. We'll call
///    setSettingsOrError when the settings change task finishes. Notice that
///    even though more deep link messages are sent with settingsOrError, only
///    the first will be taken.
///
let useRoute = () => {
  let url = ReasonReact.Router.useUrl();

  let (path, settingsOrError) =
    switch (Route.parse(url.hash)) {
    | None =>
      Js.log2("Failed to parse route: ", url.hash);
      (None, `Error(`Json_parse_error));
    | Some({Route.path, settingsOrError}) => (Some(path), settingsOrError)
    };

  let (settingsOrError, setSettingsOrError) =
    React.useState(() => settingsOrError);

  React.useEffect(() => {
    let token = MainCommunication.listen();
    Some(() => MainCommunication.stopListening(token));
  });

  (path, settingsOrError, s => setSettingsOrError(_ => s));
};

[@react.component]
let make = (~message) => {
  let (path, settingsOrError, setSettingsOrError) = useRoute();

  let closeModal = () => Router.navigate({path: Home, settingsOrError});
  let modalView =
    switch (path) {
    | None => None
    | Some(Route.Path.Send) =>
      Some(
        <Send
          closeModal
          myWallets=[
            {Wallet.key: PublicKey.ofStringExn("BK123123123"), balance: 100},
            {Wallet.key: PublicKey.ofStringExn("BK8888888"), balance: 783},
          ]
          settings={
            switch (settingsOrError) {
            | `Settings(settings) => settings
            | _ => failwith("Bad; we need settings")
            }
          }
        />,
      )
    | Some(DeleteWallet) =>
      Some(<Delete closeModal walletName="Hot Wallet" />)
    | Some(Home) => None
    };

  let randomNum = Js.Math.random_int(0, 1000);

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

  let testButton = (str, ~f) => {
    <button onClick={_e => f()}> {ReasonReact.string(str)} </button>;
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
            <Body
              message={message ++ ";; " ++ settingsInfo}
              settingsOrError
              setSettingsOrError
            />
          </div>
          {testButton("Delete wallet", ~f=() =>
             Router.(navigate({path: DeleteWallet, settingsOrError}))
           )}
          {testButton("Change name: " ++ Js.Int.toString(randomNum), ~f=() =>
             switch (settingsOrError) {
             | `Settings(settings) =>
               let task =
                 SettingsRenderer.add(
                   settings,
                   ~key=PublicKey.ofStringExn(randomNum |> Js.Int.toString),
                   ~name="Wallet " ++ Js.Int.toString(randomNum),
                 );
               Js.log("Add started");
               Task.perform(
                 task,
                 ~f=settingsOrError => {
                   Js.log2("Add complete", settingsOrError);
                   setSettingsOrError(settingsOrError);
                 },
               );
             | _ => Js.log("There's an error")
             }
           )}
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
