module NewBlock = {
  type creatorAccount = {publicKey: string};

  type snarkJobs = {prover: string};

  type userCommands = {fromAccount: string};
  type transactions = {transactions: userCommands};

  type data = {
    creatorAccount,
    userCommands,
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