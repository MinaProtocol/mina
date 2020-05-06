module NewBlock = {
  type publicKey = {publicKey: string};
  type creatorAccount = {creatorAccount: publicKey};

  type prover = {prover: string};
  type snarkJobs = {snarkJobs: prover};

  type fromAccount = {fromAccount: string};
  type userCommands = {userCommands: fromAccount};
  type transactions = {transactions: userCommands};

  type newBlock = {
    creatorAccount,
    snarkJobs,
    transactions,
  };
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