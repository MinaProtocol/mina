open BsElectron;
open Tc;

let killFaker = DaemonProcess.startFaker(8080);

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
        ~click=
          () => AppWindow.get({path: Route.Home, dispatch}) |> AppWindow.show,
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
// TODO: Also kill coda.exe
App.on(`WillQuit, () => killFaker());

let initialTask = Task.uncallbackifyValue(App.on(`Ready));

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
          initialState, ~onNewState=(_last, _curr: Application.Store.state) =>
          createTray(dispatch^)
        );
      dispatch := Application.Store.apply((), store);
      let dispatch = dispatch^;

      createTray(dispatch);

      AppWindow.deepLink({AppWindow.Input.path: Route.Home, dispatch});
    },
  );

run();
