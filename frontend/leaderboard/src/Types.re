module NewBlock = {
  type account = {publicKey: string};
  type creatorAccount = {publicKey: string};

  type snarkJobs = {prover: string};

  type userCommands = {fromAccount: account};
  type transactions = {userCommands: array(userCommands)};

  type data = {
    creatorAccount,
    snarkJobs: array(snarkJobs),
    transactions,
  };

  type newBlock = {newBlock: data};

  type t = {data: newBlock};

  external unsafeJSONToNewBlock: Js.Json.t => t = "%identity";
};

module Metrics = {
  type t =
    | BlocksCreated
    | TransactionsSent
    | SnarkWorkCreated;

  let stringOfMetric = metric => {
    switch (metric) {
    | BlocksCreated => "blocks_created"
    | TransactionsSent => "transactions_sent"
    | SnarkWorkCreated => "snarkwork_created"
    };
  };
};