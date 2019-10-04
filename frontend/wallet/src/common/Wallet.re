type t = {
  locked: option(bool),
  publicKey: PublicKey.t,
  balance: {. "total": int64},
};
