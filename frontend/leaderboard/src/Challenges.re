module StringMap = Map.Make(String);

let printMap = map => {
  StringMap.mapi(
    (key, value) => {
      Js.log(key);
      Js.log(value);
    },
    map,
  );
};

let calculateBlocksCreated = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      StringMap.update(
        block.data.newBlock.creatorAccount.publicKey,
        value =>
          switch (value) {
          | Some(blockCount) => Some(blockCount + 1)
          | None => Some(1)
          },
        map,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let calculateTransactionSent = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      Array.fold_left(
        (map, userCommand: Types.NewBlock.userCommands) => {
          StringMap.update(
            userCommand.fromAccount.publicKey,
            value =>
              switch (value) {
              | Some(transaction) => Some(transaction + 1)
              | None => Some(1)
              },
            map,
          )
        },
        map,
        block.data.newBlock.transactions.userCommands,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let calculateSnarkWorkCreated = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      Array.fold_left(
        (map, snarkJob: Types.NewBlock.snarkJobs) => {
          StringMap.update(
            snarkJob.prover,
            value =>
              switch (value) {
              | Some(snarkWork) => Some(snarkWork + 1)
              | None => Some(1)
              },
            map,
          )
        },
        map,
        block.data.newBlock.snarkJobs,
      )
    },
    StringMap.empty,
    blocks,
  );
};

// Expected Output
// {
//       "pk1": {"block_count": 1, "transactions_sent": 134, "snark_jobs": 11}
//       "pk2": {"block_count": 4, "transactions_sent": 55, "snark_jobs": 3}
//       "pk3": {"block_count": 0, "transactions_sent": 3, "snark_jobs": 8}
//}
let handleMetrics = (metrics, blocks) => {
  Types.Metrics.(
    Array.map(
      metric => {
        switch (metric) {
        | BlocksCreated => blocks |> calculateBlocksCreated
        | TransactionsSent => blocks |> calculateTransactionSent
        | _ => StringMap.empty
        }
      },
      metrics,
    )
  );
};