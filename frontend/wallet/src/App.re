open BsElectron;

let dev = true;

let sendMoney = () => {
  print_endline("Sending!");
};

let createTray = () => {
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
};

App.on(
  `Ready,
  () => {
    createTray();
    let _ = AppWindow.get();
    ();
  },
);

App.on(`WindowAllClosed, () =>
  print_endline("Closing window, menu staying open")
);

// Proof of concept on "database"
let hello_world: Js.Json.t = Js.Json.string("hello world");
Task.Result.Infix.(
  FlatFileDb.store(hello_world) >>= (() => FlatFileDb.load())
)
|> Task.fork(~f=res => {
     // the outer Result is to handle random Js exceptions that happened
     // the inner Result is the exceptions we may have accumulated from bad i/o
     let x = Result.ok_exn(Result.ok_exn(res));
     assert(x == hello_world);
     print_endline("Successfully read the data!");
   });
