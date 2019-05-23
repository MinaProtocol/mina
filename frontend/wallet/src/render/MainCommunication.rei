open Tc;

module ListenToken: {type t;};

/// Tell the main process that we changed a wallet name
let setName: (PublicKey.t, string) => Task.t('x, unit);

/// Start or stop the coda daemon
let controlCodaDaemon:
  option(list(string)) => Task.t('x, Messages.ControlCodaResponse.t);

let listen: unit => ListenToken.t;
let stopListening: ListenToken.t => unit;
