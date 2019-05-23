type t = {
  key: PublicKey.t,
  balance: string // TODO: Make this uint64
};

let ofGraphqlExn = data => {
  key: PublicKey.ofStringExn(data##publicKey),
  balance: data##balance##total,
};
