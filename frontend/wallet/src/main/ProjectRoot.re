[@bs.module "process"] external env: Js.Dict.t(string) = "";

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

let isJest = Js.Dict.get(env, "JEST_WORKER_ID") == Some("1");

let userData =
  if (!isJest && isPackaged) {
    getPath(`UserData);
  } else {
    Node.Process.cwd();
  };

let resource =
  if (!isJest && isPackaged) {
    Filename.dirname(getAppPath());
  } else {
    Node.Process.cwd();
  };

let settings = Filename.concat(userData, "settings.json");
