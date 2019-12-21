open Tc;

/// state is an immutable dictionary from public-key to name
/// Empty string values are not allowed, setting to "" is
/// equivalent to removing the name for a given key

type t = StrDict.t(string);

let empty = StrDict.empty;

let default =
  StrDict.fromList([
    (
      "tdNE67M9Snd4KF2Y3xgCQ8Res8LQxckx5xpraAAfa9uv1P6GUy8a6QkXbLnN8PknuKDknEerRCYGujScean4D88v5sJcTqiuqnr2666Csc8QhpUW6MeXq7MgEha7S6ttxB3bY9MMVrDNBB",
      "Faucet",
    ),
    (
      "tdNDk6tKpzhVXUqozR5y2r77pppsEak7icvdYNsv2dbKx6r69AGUUbQsfrHHquZipQCmMj4VRhVF3u4F5NDgdbuxxWANULyVjUYPbe85fv7bpjKRgSpGR3zo2566s5GNNKQyLRUm12wt5o",
      "Echo Service",
    ),
  ]);

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
