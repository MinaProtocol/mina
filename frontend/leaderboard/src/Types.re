module NewBlock = {
  type account = {publicKey: string};

  type snarkJobs = {prover: string};

  type userCommands = {fromAccount: account};
  type transactions = {userCommands: array(userCommands)};

  type data = {
    creatorAccount: account,
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
    | Some(BlocksCreated) => "blocks_created"
    | Some(TransactionsSent) => "transactions_sent"
    | Some(SnarkWorkCreated) => "snarkwork_created"
    | None => ""
    };
  };

  let metricOfString = metric => {
    switch (metric) {
    | "blocks_created" => Some(BlocksCreated)
    | "transactions_sent" => Some(TransactionsSent)
    | "snarkwork_created" => Some(SnarkWorkCreated)
    | _ => None
    };
  };
};