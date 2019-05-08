open Tc;

module Settings_intf = Settings.Intf(Result);

type saveSettings('a) =
  Settings.t => Task.t([> | `Error_saving_file(Js.Exn.t)] as 'a, unit);

[@bs.val] [@bs.scope "window"]
external loadSettings: Settings_intf.loadSettings(unit, 'a) = "";

[@bs.val] [@bs.scope "window"] external saveSettings: saveSettings('a) = "";

let lookup = Settings.lookup;

let entries = Settings.entries;

let lookupWithFallback = (t, key: PublicKey.t) =>
  lookup(t, key) |> Option.withDefault(~default=PublicKey.toString(key));

let add = (t: Settings.t, ~key, ~name) => {
  let t' = Settings.set(t, ~key, ~name);

  saveSettings(t')
  |> Task.andThen(~f=() => MainCommunication.setName(key, name))
  |> Task.map(~f=() => t');
};
