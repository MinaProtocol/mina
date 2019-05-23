open Tc;

/// state is an immutable dictionary from public-key to name

type t = StrDict.t(string);

let empty = StrDict.empty;

let fromJsonString = jsonStr => {
  let json = Js.Json.parseExn(jsonStr);
  let jsDict = Json.Decode.(json |> dict(string));
  Js.Dict.entries(jsDict) |> Array.toList |> StrDict.fromList;
};

let toJsonString = t => {
  t
  |> StrDict.toList
  |> List.map(~f=((a, b)) => (a, Js.Json.string(b)))
  |> Js.Dict.fromList
  |> Js.Json.object_
  |> Js.Json.stringify;
};

let lookup = (t, key: PublicKey.t) =>
  StrDict.get(t, ~key=PublicKey.toString(key));

let set = (t, ~key, ~name) =>
  StrDict.insert(t, ~key=PublicKey.toString(key), ~value=name);

let getWalletName = (t, key: PublicKey.t) =>
  lookup(t, key) |> Option.withDefault(~default=PublicKey.prettyPrint(key));
