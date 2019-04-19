open Tc;
open Settings;

let file = "settings.json";

let load = () =>
  FlatFileDb.load(file)
  |> Task.andThen(~f=json =>
       try (Decode.t(json) |> Task.succeed) {
       | Json.Decode.DecodeError(str) => Task.fail(`Decode_error(str))
       }
     );

let store = t => FlatFileDb.store(file, t);

let lookup = Settings.lookup;

let add = (t, ~key: PublicKey.t, ~name: string) => {
  Js.Dict.set(t.state, PublicKey.toString(key), name);
  store(Encode.t(t));
};
