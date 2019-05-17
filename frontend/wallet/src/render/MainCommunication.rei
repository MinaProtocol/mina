open Tc;

module ListenToken: {type t;};

/// Tell the main process that we changed a wallet name
let setName: (PublicKey.t, string) => Task.t('x, unit);

let listen: unit => ListenToken.t;
let stopListening: ListenToken.t => unit;
