open Tc;

/// state is an immutable dictionary from public-key to name
/// Empty string values are not allowed, setting to "" is
/// equivalent to removing the name for a given key

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

let lookup = (t: StrDict.t(string), key: PublicKey.t) =>
  StrDict.get(t, ~key=PublicKey.toString(key))
  |> Option.andThen(
       ~f=
         fun
         | "" => None
         | x => Some(x),
     );

let set = (t: StrDict.t(string), ~key, ~name) =>
  if (name == "") {
    StrDict.update(t, ~key=PublicKey.toString(key), ~f=_ => None);
  } else {
    StrDict.insert(t, ~key=PublicKey.toString(key), ~value=name);
  };
