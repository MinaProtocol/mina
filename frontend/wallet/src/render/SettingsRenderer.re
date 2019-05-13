open Tc;

module Settings_intf = Settings.Intf(Result);

type saveSettings('a) =
  Settings.t => Task.t([> | `Error_saving_file(Js.Exn.t)] as 'a, unit);

[@bs.val] [@bs.scope "window"]
external loadSettings: Settings_intf.loadSettings(unit, 'a) = "";

[@bs.val] [@bs.scope "window"] external saveSettings: saveSettings('a) = "";

let lookup = (t, key) => Option.andThen(t, ~f=t => Settings.lookup(t, key));

let entries = Settings.entries;

let getWalletName = (t, key: PublicKey.t) =>
  lookup(t, key) |> Option.withDefault(~default=PublicKey.prettyPrint(key));

let add = (t: Settings.t, ~key, ~name) => {
  let t' = Settings.set(t, ~key, ~name);

  saveSettings(t')
  |> Task.andThen(~f=() => MainCommunication.setName(key, name))
  |> Task.map(~f=() => t');
};
