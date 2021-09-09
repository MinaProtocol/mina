// TODO: Put this somewhere and implement properly
module ProvingKey = {
  // path to a file
  type t = string;
};

module General = {
  type t = {testnet: Url.t};
};

module Accounts = {
  type t = option(PublicKey.t);
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

  type t = option(Form.t);
};

type t = {
  general: General.t,
  compression: Compression.t,
  accounts: Accounts.t,
};

let default = (~testnet) => {
  general: {
    General.testnet: testnet,
  },
  compression: None,
  accounts: None,
};
