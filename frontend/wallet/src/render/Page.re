open Tc;

let component = ReasonReact.statelessComponent("Page");

let inMemoryCache = ApolloInMemoryCache.createInMemoryCache();
let ipcLink = IpcLinkRenderer.create();
let instance =
  ReasonApollo.createApolloClient(~link=ipcLink, ~cache=inMemoryCache, ());

/// The semantics are as follows:
///
/// 1. Path is always aquired from a URL.
/// 2. We listen to the main process for new routes while the page is open
///
let useRoute = () => {
  let url = ReasonReact.Router.useUrl();

  let path = Route.parse(url.hash);

  switch (path) {
  | None => Js.log2("Failed to parse route: ", url.hash)
  | Some(_) => ()
  };

  React.useEffect(() => {
    let token = MainCommunication.listen();
    Some(() => MainCommunication.stopListening(token));
  });

  path;
};

let useSettings = () => {
  let (settings, setSettings) =
    React.useState(() => SettingsRenderer.loadSettings());

  (settings, newVal => setSettings(_ => newVal));
};

[@react.component]
let make = (~message) => {
  let path = useRoute();
  let (settingsOrError, setSettingsOrError) = useSettings();

  let closeModal = () => Router.navigate(Home);
  let modalView =
    switch (path) {
    | None => None
    | Some(Route.Send) =>
      Some(
        <Send
          closeModal
          myWallets=[
            {Wallet.key: PublicKey.ofStringExn("BK123123123"), balance: 100},
            {Wallet.key: PublicKey.ofStringExn("BK8888888"), balance: 783},
          ]
          settings={
            switch (settingsOrError) {
            | Ok(settings) => settings
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
    | Ok(_) => "Settings loaded successfully"
    | Error(`Json_parse_error) =>
      "Settings failed to load with a json parse error" ++ question
    | Error(`Decode_error(s)) =>
      "Settings failed to decode with " ++ s ++ question
    | Error(`Error_saving_file(e)) =>
      "Settings failed to write with a js exception"
      ++ question
      ++ (Js.Exn.stack(e) |> Option.withDefault(~default=""))
    | Error(`Error_reading_file(e)) =>
      "Settings failed to load with a js exception"
      ++ question
      ++ (Js.Exn.stack(e) |> Option.withDefault(~default=""))
    };
  };

  let testButton = (str, ~f) => {
    <button onClick={_e => f()}> {ReasonReact.string(str)} </button>;
  };
  <ReasonApollo.Provider client=instance>
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
             Router.(navigate(DeleteWallet))
           )}
          {testButton("Change name: " ++ Js.Int.toString(randomNum), ~f=() =>
             switch (settingsOrError) {
             | Ok(settings) =>
               let task =
                 SettingsRenderer.add(
                   settings,
                   ~key=PublicKey.ofStringExn(randomNum |> Js.Int.toString),
                   ~name="Wallet " ++ Js.Int.toString(randomNum),
                 );
               Js.log("Add started");
               Task.attempt(
                 task,
                 ~f=res => {
                   Js.log2("Add complete", res);
                   setSettingsOrError(res);
                 },
               );
             | _ => Js.log("There's an error")
             }
           )}
        </div>
        <div>
          {switch (settingsOrError) {
           | Ok(settings) =>
             <Footer
               stakingKey={PublicKey.ofStringExn("131243123")}
               settings
             />
           | Error(_) => <span />
           }}
          <Modal view=modalView />
        </div>
      </div>
    </div>
  </ReasonApollo.Provider>;
};
