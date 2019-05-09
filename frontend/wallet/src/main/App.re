open BsElectron;
open Tc;

let killDaemon = DaemonProcess.start(8080);
let apolloClient = GraphqlMain.createClient("http://localhost:8080/graphql");

IpcLinkMain.start(apolloClient);

let createTray = dispatch => {
  let t = AppTray.get();
  let trayItems =
    Menu.Item.[
      make(
        Label("Synced"),
        ~icon=Filename.concat(ProjectRoot.resource, "public/circle-16.png"),
        (),
      ),
      make(Separator, ()),
      make(
        Label("Debug"),
        ~click=
          () =>
            AppWindow.get({path: Route.Home, dispatch})
            |> AppWindow.openDevTools,
        (),
      ),
      make(Separator, ()),
      make(
        Label("Open"),
        ~accelerator="CmdOrCtrl+O",
        ~click=() => AppWindow.deepLink({path: Route.Home, dispatch}),
        (),
      ),
      make(
        Label("Settings"),
        ~accelerator="CmdOrCtrl+,",
        ~click=() => AppWindow.deepLink({path: Route.Home, dispatch}),
        (),
      ),
      make(Separator, ()),
      make(Label("Quit"), ~accelerator="CmdOrCtrl+Q", ~role="quit", ()),
    ];

  let menu = Menu.make();
  List.iter(~f=Menu.append(menu), trayItems);

  Tray.setContextMenu(t, menu);
};

// We need this handler here to prevent the application from exiting on all
// windows closed. Keep in mind, we have the tray.
App.on(`WindowAllClosed, () => ());
App.on(`WillQuit, () => killDaemon());

module Test = [%graphql {| query { wallets {publicKey} } |}];
module TestQuery = GraphqlMain.CreateQuery(Test);

let initialTask =
  Task.map2(
    Task.uncallbackifyValue(App.on(`Ready)),
    SettingsMain.load(ProjectRoot.settings),
    ~f=((), settings) =>
    settings
  );

let run = () =>
  Task.attempt(
    initialTask,
    ~f=settingsOrError => {
      let initialState = {Application.State.settingsOrError, wallets: [||]};

      let dispatch = ref(_ => ());
      let store =
        Application.Store.create(
          initialState, ~onNewState=(_last, _curr: Application.State.t('a)) =>
          createTray(dispatch^)
        );
      dispatch := Application.Store.apply(store);
      let dispatch = dispatch^;

      createTray(dispatch);

      AppWindow.deepLink({AppWindow.Input.path: Route.Home, dispatch});
    },
  );

run();
