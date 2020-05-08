open BsElectron;
open Tc;

[@bs.module "electron"] [@bs.scope "shell"] [@bs.val]
external openItem: string => unit = "openItem";

let createTray = dispatch => {
  let t = AppTray.get();
  let trayItems =
    Menu.Item.[
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
        ~click=() => AppWindow.deepLink({path: Route.Settings, dispatch}),
        (),
      ),
      make(
        Label("View logs"),
        ~accelerator="CmdOrCtrl+L",
        ~click=() => openItem(DaemonProcess.Process.logfileName),
        (),
      ),
      make(Separator, ()),
      make(Label("Quit"), ~accelerator="CmdOrCtrl+Q", ~role="quit", ()),
    ];

  let menu = Menu.make();
  List.iter(~f=Menu.append(menu), trayItems);

  Tray.setContextMenu(t, menu);
};

let createApplicationMenu = () => {
  let menuItems =
    Menu.Item.[
      make(
        Submenu(
          "Application",
          [|
            make(
              Label("About"),
              ~selector="orderFrontStandardAboutPanel",
              (),
            ),
            make(Separator, ()),
            make(
              Label("Quit"),
              ~accelerator="CmdOrCtrl+Q",
              ~role="quit",
              (),
            ),
          |],
        ),
        (),
      ),
      make(
        Submenu(
          "Edit",
          [|
            make(
              Label("Cut"),
              ~accelerator="CmdOrCtrl+X",
              ~selector="cut:",
              (),
            ),
            make(
              Label("Copy"),
              ~accelerator="CmdOrCtrl+C",
              ~selector="copy:",
              (),
            ),
            make(
              Label("Paste"),
              ~accelerator="CmdOrCtrl+V",
              ~selector="paste:",
              (),
            ),
          |],
        ),
        (),
      ),
    ];

  let menu = Menu.make();
  List.iter(~f=Menu.append(menu), menuItems);
  Menu.setApplicationMenu(menu);
};

// We need this handler here to prevent the application from exiting on all
// windows closed. Keep in mind, we have the tray.
BsElectron.App.on(`WindowAllClosed, () => ());

let initialTask = Task.uncallbackifyValue(BsElectron.App.on(`Ready));

let run = () =>
  Task.attempt(
    initialTask,
    ~f=_ => {
      let initialState = {
        Application.State.coda:
          Application.State.CodaProcessState.Stopped(Belt.Result.Ok()),
        window: None,
      };

      let dispatch = ref(_ => ());
      let store =
        Application.Store.create(
          initialState,
          ~onNewState=(_last, _curr: Application.Store.state) => {
            createTray(dispatch^);
            createApplicationMenu();
          },
        );
      dispatch := Application.Store.apply((), store);
      let dispatch = dispatch^;

      BsElectron.App.on(`WillQuit, () => dispatch(Action.ControlCoda(None)));
      createTray(dispatch);
      createApplicationMenu();

      DaemonProcess.CodaProcess.(start(defaultArgs)) |> ignore;

      AppWindow.deepLink({AppWindow.Input.path: Route.Home, dispatch});
    },
  );

run();
