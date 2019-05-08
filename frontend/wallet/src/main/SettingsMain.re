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
  //      Note, if we reload from disk we need to make sure we atomically
  //      finish writing from settings before reloading here (we may have to
  //      setup some sort of lockfile system.
  Task.return @@ Settings.set(t, ~key, ~name);
};
