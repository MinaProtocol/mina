module ListenToken: {type t;};

/// Start or stop the mina daemon
/// Afterwards you'll poll the graphql endpoint until it succeeds
let controlCodaDaemon: option(list(string)) => unit;

let listen: unit => ListenToken.t;
let stopListening: ListenToken.t => unit;
