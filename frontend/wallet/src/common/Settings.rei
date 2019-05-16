open Tc;

/// Settings contains a (semantically) immutable dictionary mapping public keys
/// to names
type t;

module Decode: {
  /// Throws on decode failure because bs-json :(
  let t: Js.Json.t => t;
};

module Encode: {let t: t => Js.Json.t;};

let lookup: (t, PublicKey.t) => option(string);

let entries: t => array((PublicKey.t, string));

let set: (t, ~key: PublicKey.t, ~name: string) => t;

module Intf:
  (M: Monad.Fail.S2) =>
   {
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

module Loader: {
  module Make:
    (
      M: Monad.Fail.S2,
      R: {let readSettings: string => M.t(Js.Exn.t, string);},
    ) =>
     {let load: Intf(M).loadSettings(string, 'a);};
};
