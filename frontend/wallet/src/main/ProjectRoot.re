open Tc;

[@bs.module "electron"] [@bs.scope "app"] external isPackaged: bool = "";

[@bs.module "electron"] [@bs.scope "app"]
external getAppPath: unit => string = "";

[@bs.module "electron"] [@bs.scope "app"]
external getPath:
  (
  [@bs.string]
  [
    | [@bs.as "home"] `Home
    | [@bs.as "appData"] `AppData
    | [@bs.as "userData"] `UserData
    | [@bs.as "temp"] `Temp
    | [@bs.as "exe"] `Exe
    | [@bs.as "module"] `Module
    | [@bs.as "desktop"] `Desktop
    | [@bs.as "documents"] `Documents
    | [@bs.as "download"] `Downloads
    | [@bs.as "music"] `Music
    | [@bs.as "pictures"] `Pictures
    | [@bs.as "videos"] `Videos
    | [@bs.as "logs"] `Logs
  ]
  ) =>
  string =
  "";

let userData =
  if (isPackaged) {
    getPath(`UserData);
  } else {
    Node_path.join2(Option.getExn([%bs.node __dirname]), "../../../..");
  };

let resource =
  if (isPackaged) {
    Filename.dirname(getAppPath());
  } else {
    Node_path.join2(Option.getExn([%bs.node __dirname]), "../../../..");
  };
