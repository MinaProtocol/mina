open Tc;
/* exception Json_parse_error; */
let readFileAsync = path =>
  Task.uncallbackify(Bindings.Fs.readFile(path, "utf-8"));

include Settings.Loader.Make(
          Tc.Task,
          {
            let readSettings = readFileAsync;
          },
        );

let lookup = Settings.lookup;

let add = (t, ~key: PublicKey.t, ~name: string) => {
  // TODO: Should we instead just reload from disk?
  Task.return @@ Settings.set(t, ~key, ~name);
};
