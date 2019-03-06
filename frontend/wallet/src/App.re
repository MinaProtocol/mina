open BsElectron;

let win = ref(Js.null);

let dev = true;

module AppBrowserWindow = BrowserWindow.MakeBrowserWindow(Messages);

let createWindow = () => {
  win :=
    Js.Null.return(
      AppBrowserWindow.makeWindowConfig(
        ~transparent=true,
        ~width=800,
        ~height=500,
        ~frame=false,
        ~fullscreenable=false,
        ~resizeable=false,
        ~title="Coda Wallet",
        ~backgroundColor="#EE112b56",
        (),
      )
      ->AppBrowserWindow.make,
    );

  let bundleLocation =
    Node_path.join([|
      Belt.Option.getExn([%bs.node __dirname]),
      "../../../index.html",
    |]);
  AppBrowserWindow.loadURL(
    Js.Null.getExn(win^),
    "file://" ++ bundleLocation,
  );

  AppBrowserWindow.on(Js.Null.getExn(win^), `Closed, () => win := Js.null);
};

App.on(`Ready, () => createWindow());
