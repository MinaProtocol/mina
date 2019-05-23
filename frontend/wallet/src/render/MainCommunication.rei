open Tc;

module ListenToken: {type t;};

/// Start or stop the coda daemon
let controlCodaDaemon:
  option(list(string)) => Task.t('x, Messages.ControlCodaResponse.t);

let listen: unit => ListenToken.t;
let stopListening: ListenToken.t => unit;
