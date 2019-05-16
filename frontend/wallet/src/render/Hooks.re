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

let useActiveWallet = () => {
  let url = ReasonReact.Router.useUrl();  
  switch (url.path) {
  | ["wallet", walletKey] => Some(PublicKey.ofStringExn(walletKey))
  | _ => None
  };
};
