open Tc;
/* exception Json_parse_error; */
let readFileAsync = path =>
  Task.uncallbackify(Bindings.Fs.readFile(path, "utf-8"));

let writeFileAsync = (path, data) =>
  Task.uncallbackify0(Bindings.Fs.writeFile(path, data, "utf-8"));

let file = "settings.json";

let load = () => {
  let settingsLocation = Filename.concat(ProjectRoot.userData, file);
  readFileAsync(settingsLocation)
  |> Task.map(~f=v => `Json(v))
  |> Task.onError(~f=e => Task.succeed(`Error_reading_file(e)))
  |> Task.andThen(~f=contents =>
       switch (contents) {
       | `Json(contents) =>
         switch (Json.parse(contents)) {
         | Some(json) => Task.succeed(json)
         | None => Task.fail(`Json_parse_error)
         }
       | `Error_reading_file(e) =>
         Printf.fprintf(
           stderr,
           "Error loading settings from %s, falling back to default. Error:%s\n%!",
           settingsLocation,
           Tc.Option.withDefault(Js.Exn.message(e), ~default="Unknown"),
         );
         Task.succeed(Settings.create());
       }
     )
  |> Task.andThen(~f=json =>
       try (Settings.Decode.t(json) |> Task.succeed) {
       | Json.Decode.DecodeError(str) => Task.fail(`Decode_error(str))
       }
     );
};

let store = t =>
  writeFileAsync(
    Filename.concat(ProjectRoot.userData, file),
    Js.Json.stringify(t),
  )
  |> Task.mapError(~f=e => `Js_exn(e));

let lookup = Settings.lookup;

let add = (t: Settings.t, ~key: PublicKey.t, ~name: string) => {
  Js.Dict.set(t.state, PublicKey.toString(key), name);
  store(Settings.Encode.t(t));
};
