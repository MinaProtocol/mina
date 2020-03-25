let downloadRoot = "https://s3-us-west-1.amazonaws.com/proving-key-2018-10-01/";

let downloadKey = (keyName, chunkCb, doneCb) =>
  DownloadLogic.download(
    keyName,
    downloadRoot ++ keyName,
    "binary",
    1,
    chunkCb,
    doneCb,
  );

let downloadCoda = (version, chunkCb, doneCb) =>
  DownloadLogic.downloadCoda(version, chunkCb, doneCb);

[@bs.module "electron"] [@bs.scope "shell"] [@bs.val]
external showItemInFolder: string => unit = "showItemInFolder";

let showItemInFolder = showItemInFolder;

[@bs.module "electron"] [@bs.scope "shell"] [@bs.val]
external openExternal: string => unit = "openExternal";

let openExternal = openExternal;

let isFaker =
  Js.Dict.get(Bindings.ChildProcess.Process.env, "GRAPHQL_BACKEND")
  == Some("faker");

let getTranslation = name =>
  Bindings.Fs.readFileSync(
    "./public/translations/" ++ name ++ ".json",
    "utf8",
  );

[%bs.raw "window.isFaker = isFaker"];
[%bs.raw "window.downloadKey = downloadKey"];
[%bs.raw "window.downloadCoda = downloadCoda"];
[%bs.raw "window.showItemInFolder = showItemInFolder"];
[%bs.raw "window.openExternal = openExternal"];
[%bs.raw "window.hotReloadLocation = window.location"];
[%bs.raw
  "window.fileRoot = require(\"path\").dirname(window.location.pathname)"
];
[%bs.raw
  "window.reload = function () { window.location = window.hotReloadLocation }"
];
[%bs.raw "window.getTranslation = getTranslation"];
