open Tc;

/// state is a dictionary from public-key to name
type t = {state: Js.Dict.t(string)};

// TODO: Replace with something more automated like quicktype
module Decode = {
  let state = json => Json.Decode.(json |> field("state", dict(string)));

  let t = json => {state: state(json)};
};

module Encode = {
  let state = dict =>
    Js.Dict.map((. a) => Json.Encode.string(a), dict) |> Json.Encode.dict;

  let t = t => Json.Encode.object_([("state", state(t.state))]);
};

let lookup = (t, key: PublicKey.t) =>
  Js.Dict.get(t.state, PublicKey.toString(key));

module type S = {
  let lookup: (t, PublicKey.t) => option(string);
  let add:
    (t, ~key: PublicKey.t, ~name: string) =>
    Task.t([> | `Js_exn(Js.Exn.t)], unit);
};
