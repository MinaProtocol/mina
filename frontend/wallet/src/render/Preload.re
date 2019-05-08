open Tc;

let writeFileAsync = (path, data) =>
  Task.uncallbackify0(Bindings.Fs.writeFile(path, data, "utf-8"));

include Settings.Loader.Make(
          Result,
          {
            let readSettings = settingsLocation =>
              try (
                Node.Fs.readFileSync(settingsLocation, `utf8) |> Result.return
              ) {
              | e => Result.fail(Js.Exn.asJsExn(e) |> Option.getExn)
              };
          },
        );

let settingsPath = {
  let url = [%bs.raw "window.location.href"];
  let searchParams = Bindings.Url.create(url) |> Bindings.Url.searchParams;

  Bindings.Url.SearchParams.get(searchParams, "settingsPath")
  |> Js.Global.decodeURI;
};

// TODO: Is exposing a writeFile to this particular path, still too large of an
// attack vector? An adversary could send a super large settings payload for
// example.
let saveSettings: SettingsRenderer.saveSettings('a) =
  settings =>
    writeFileAsync(
      settingsPath,
      Js.Json.stringify(Settings.Encode.t(settings)),
    )
    |> Task.onError(~f=e => Task.fail(`Error_saving_file(e)));

let loadSettings: Settings.Intf(Result).loadSettings(unit, 'a) =
  () => load(settingsPath);

[%bs.raw "window.loadSettings = loadSettings"];
[%bs.raw "window.saveSettings = saveSettings"];
