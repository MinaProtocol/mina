// TODO: Put this somewhere and implement properly
module ProvingKey = {
  // path to a file
  type t = string;
};

module WithKey = {
  type t('a) =
    | NoKey
    | Key(ProvingKey.t, 'a);
};

module General = {
  type t = {testnet: Url.t};
};

module Wallets = {
  type t = WithKey.t(option(PublicKey.t));
};

module Compression = {
  module Form = {
    type t = {
      coordinator: Url.t,
      payoutKey: PublicKey.t,
      reward: int64,
      enabled: bool,
    };
  };

  type t = WithKey.t(Form.t);
};

type t = {
  general: General.t,
  compression: Compression.t,
  wallets: Wallets.t,
};

let default = (~testnet) => {
  general: {
    General.testnet: testnet,
  },
  compression: WithKey.NoKey,
  wallets: WithKey.NoKey,
};
