open BsElectron;
open Tc;

let killDaemon = DaemonProcess.start(8080);
let apolloClient = GraphqlMain.createClient("http://localhost:8080/graphql");

IpcLinkMain.start(apolloClient);

let createTray = (settingsOrError, wallets) => {
  let t = AppTray.get();
  let prefixItems =
    Menu.Item.[
      make(
        Label("Synced"),
        ~icon=Filename.concat(ProjectRoot.resource, "public/circle-16.png"),
        (),
      ),
      make(Separator, ()),
      make(Label("Wallets:"), ~enabled=false, ()),
    ];
  let codaSymbol = {js|□|js};
  let walletItems =
    switch (wallets) {
    | Some(wallets) =>
      List.map(
        ~f=
          wallet =>
            Menu.Item.make(
              Radio(
                Printf.sprintf(
                  "    %s %s %d",
                  wallet##publicKey,
                  codaSymbol,
                  100,
                ),
              ),
              (),
            ),
        Array.to_list(wallets),
      )

    | None => Menu.Item.[make(Label({js|    Loading...|js}), ())]
    };

  let suffixItems =
    Menu.Item.[
      make(Separator, ()),
      make(
        Label("Send"),
        ~accelerator="CmdOrCtrl+S",
        ~click=() => AppWindow.deepLink({path: Route.Send, settingsOrError}),
        (),
      ),
      make(Separator, ()),
      make(Label("Request"), ~accelerator="CmdOrCtrl+R", ()),
      make(Separator, ()),
      make(Label("Settings:"), ~enabled=false, ()),
      make(Checkbox("    Snark worker"), ()),
      make(Separator, ()),
      make(Label("Quit"), ~accelerator="CmdOrCtrl+Q", ~role="quit", ()),
    ];

  let menu = Menu.make();
  List.iter(~f=Menu.append(menu), prefixItems @ walletItems @ suffixItems);

  Tray.setContextMenu(t, menu);
};

// We need this handler here to prevent the application from exiting on all
// windows closed. Keep in mind, we have the tray.
App.on(`WindowAllClosed, () => ());
App.on(`WillQuit, () => killDaemon());

let task =
  Task.map2(
    Task.uncallbackifyValue(App.on(`Ready)),
    SettingsMain.load(ProjectRoot.settings),
    ~f=((), settings) =>
    settings
  );

module Test = [%graphql {| query { wallets {publicKey} } |}];
module TestQuery = GraphqlMain.CreateQuery(Test);

Task.attempt(
  task,
  ~f=settingsOrError => {
    // TODO: Periodically poll this and/or use a subscription
    ignore @@
    Js.Global.setTimeout(
      () => {
        let q = TestQuery.query(apolloClient);
        Task.perform(q, ~f=response =>
          switch (response.data) {
          | Some(d) => createTray(settingsOrError, Some(d##wallets))
          | None => Js.log("Error getting wallets")
          }
        );
      },
      2000,
    );

    createTray(settingsOrError, None);
    AppWindow.deepLink({AppWindow.Input.path: Route.Home, settingsOrError});
  },
);
