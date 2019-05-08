open Tc;

/// state is an immutable dictionary from public-key to name
type t = {state: Js.Dict.t(string)};

let create = () =>
  Js.Json.object_(
    Js.Dict.fromList([("state", Js.Json.object_(Js.Dict.empty()))]),
  );

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

let set = (t: t, ~key, ~name) => {
  let state' = Js.Dict.entries(t.state) |> Js.Dict.fromArray;
  Js.Dict.set(state', PublicKey.toString(key), name);
  {state: state'};
};

module Intf = (M: Monad.Fail.S2) => {
  type loadSettings('input, 'a) =
    'input => M.t([> | `Decode_error(string) | `Json_parse_error] as 'a, t);

  module type S = {
    let lookup: (t, PublicKey.t) => option(string);
    let add:
      (t, ~key: PublicKey.t, ~name: string) =>
      Task.t([> | `Decode_error(string) | `Json_parse_error], t);
    let load: loadSettings(string, 'a);
  };
};

module Loader = {
  module Make =
         (
           M: Monad.Fail.S2,
           R: {let readSettings: string => M.t(Js.Exn.t, string);},
         ) => {
    let load = path =>
      R.readSettings(path)
      |> M.map(~f=v => `Json(v))
      |> M.onError(~f=e => M.return(`Error_reading_file(e)))
      |> M.andThen(~f=contents =>
           switch (contents) {
           | `Json(contents) =>
             Js.log2("contents", contents);
             switch (Json.parse(contents)) {
             | Some(json) => M.return(json)
             | None => M.fail(`Json_parse_error)
             };
           | `Error_reading_file(e) =>
             Printf.fprintf(
               stderr,
               "Error loading settings from %s, falling back to default. Error:%s\n%!",
               path,
               Tc.Option.withDefault(Js.Exn.message(e), ~default="Unknown"),
             );
             M.return(create());
           }
         )
      |> M.andThen(~f=json =>
           try (Decode.t(json) |> M.return) {
           | Json.Decode.DecodeError(str) => M.fail(`Decode_error(str))
           }
         );
  };
};
