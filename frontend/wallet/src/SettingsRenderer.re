open Tc;

let lookup = Settings.lookup;

let entries = (t: Settings.t) =>
  Js.Dict.entries(t.state)
  |> Array.map(~f=((key, name)) => (PublicKey.ofStringExn(key), name));

let lookupWithFallback = (t, key: PublicKey.t) =>
  lookup(t, key) |> Option.withDefault(~default=PublicKey.toString(key));

let add = (_t, ~key, ~name) => {
  MainCommunication.setName(key, name);
};
