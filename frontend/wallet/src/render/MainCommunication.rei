open Tc;

module ListenToken: {type t;};

let setName: (PublicKey.t, string) => Task.t('x, Route.SettingsOrError.t);

let listen: unit => ListenToken.t;
let stopListening: ListenToken.t => unit;
