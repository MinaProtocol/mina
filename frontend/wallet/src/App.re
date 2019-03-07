open BsElectron;

let win = ref(Js.null);

let tray = ref(Js.null);

let dev = true;

let projectRoot =
  Node_path.join2(Belt.Option.getExn([%bs.node __dirname]), "../../../");

module AppBrowserWindow = BrowserWindow.MakeBrowserWindow(Messages);
let createWindow = () => {
  win :=
    Js.Null.return(
      AppBrowserWindow.make(
        AppBrowserWindow.makeWindowConfig(
          ~transparent=true,
          ~width=880,
          ~height=500,
          ~frame=false,
          ~fullscreenable=false,
          ~resizeable=false,
          ~title="Coda Wallet",
          ~backgroundColor="#DD" ++ Styles.Colors.(hexToString(bgColor)),
          (),
        ),
      ),
    );

  AppBrowserWindow.loadURL(
    Js.Null.getExn(win^),
    "file://" ++ projectRoot ++ "public/index.html",
  );
  Js.log("file://" ++ projectRoot ++ "public/index.html");
  AppBrowserWindow.on(Js.Null.getExn(win^), `Closed, () => win := Js.null);
};

let sendMoney = () => {
  print_endline("Sending!");
};

let createTray = () => {
  let t = Tray.make(projectRoot ++ "public/icon.png");
  let items =
    Menu.Item.[
      make(Label("Synced"), ~icon=projectRoot ++ "public/circle-16.png", ()),
      make(Separator, ()),
      make(Label("Wallets:"), ~enabled=false, ()),
      make(Radio({js|    Wallet_1  □ 100|js}), ()),
      make(Radio({js|    Vault  □ 100,000|js}), ()),
      make(Separator, ()),
      make(Label("Send"), ~accelerator="CmdOrCtrl+S", ~click=sendMoney, ()),
      make(Separator, ()),
      make(Label("Request"), ~accelerator="CmdOrCtrl+R", ()),
      make(Separator, ()),
      make(Label("Settings:"), ~enabled=false, ()),
      make(Checkbox("    Snark_worker"), ()),
      make(Separator, ()),
      make(Label("Quit"), ~accelerator="CmdOrCtrl+Q", ~role="quit", ()),
    ];

  let menu = Menu.make();
  List.iter(Menu.append(menu), items);

  Tray.setContextMenu(t, menu);
  tray := Js.Null.return(t);
};

App.on(
  `Ready,
  () => {
    createTray();
    createWindow();
  },
);
