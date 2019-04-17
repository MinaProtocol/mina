open BsElectron;
open Tc;

let dev = true;

let createTray = settingsOrError => {
  let t = AppTray.get();
  let items =
    Menu.Item.[
      make(
        Label("Synced"),
        ~icon=ProjectRoot.path ++ "public/circle-16.png",
        (),
      ),
      make(Separator, ()),
      make(Label("Wallets:"), ~enabled=false, ()),
      make(Radio({js|    Wallet_1  □ 100|js}), ()),
      make(Radio({js|    Vault  □ 100,000|js}), ()),
      make(Separator, ()),
      make(
        Label("Send"),
        ~accelerator="CmdOrCtrl+S",
        ~click=
          () => AppWindow.deepLink({path: Route.Path.Send, settingsOrError}),
        (),
      ),
      make(Separator, ()),
      make(Label("Request"), ~accelerator="CmdOrCtrl+R", ()),
      make(Separator, ()),
      make(Label("Settings:"), ~enabled=false, ()),
      make(Checkbox("    Snark_worker"), ()),
      make(Separator, ()),
      make(Label("Quit"), ~accelerator="CmdOrCtrl+Q", ~role="quit", ()),
    ];

  let menu = Menu.make();
  List.iter(~f=Menu.append(menu), items);

  Tray.setContextMenu(t, menu);
};

// We need this handler here to prevent the application from exiting on all
// windows closed. Keep in mind, we have the tray.
App.on(`WindowAllClosed, () => ());

let task =
  Task.map2(
    Task.uncallbackifyValue(App.on(`Ready)),
    SettingsMain.load(),
    ~f=((), settings) =>
    `Settings(settings)
  )
  |> Task.onError(~f=e => Task.succeed(`Error(e)));

Task.perform(
  task,
  ~f=settingsOrError => {
    // TODO: Send whatever settings are relevant to the relevant pieces
    createTray(settingsOrError);
    AppWindow.deepLink({path: Route.Path.Home, settingsOrError});
  },
);
