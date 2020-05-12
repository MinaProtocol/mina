module StringMap = Map.Make(String);

// Helper functions for gathering metrics
let printMap = map => {
  StringMap.mapi(
    (key, value) => {
      Js.log(key);
      Js.log(value);
    },
    map,
  );
};

let calculateProperty = (f, blocks) => {
  blocks
  |> Array.fold_left((map, block) => {f(map, block)}, StringMap.empty);
};

let incrementMapValue = (key, map) => {
  map
  |> StringMap.update(key, value => {
       switch (value) {
       | Some(valueCount) => Some(valueCount + 1)
       | None => Some(1)
       }
     });
};

// Gather metrics
let getBlocksCreatedByUser = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.data) => {
         incrementMapValue(block.creatorAccount.publicKey, map)
       },
       StringMap.empty,
     );
};

let calculateTransactionSent = (map, block: Types.NewBlock.data) => {
  block.transactions.userCommands
  |> Array.fold_left(
       (transactionMap, userCommand: Types.NewBlock.userCommands) => {
         incrementMapValue(userCommand.fromAccount.publicKey, transactionMap)
       },
       map,
     );
};

let getTransactionSentByUser = blocks => {
  blocks |> calculateProperty(calculateTransactionSent);
};

let calculateSnarkWorkCount = (map, block: Types.NewBlock.data) => {
  block.snarkJobs
  |> Array.fold_left(
       (snarkMap, snarkJob: Types.NewBlock.snarkJobs) => {
         incrementMapValue(snarkJob.prover, snarkMap)
       },
       map,
     );
};

let getSnarkWorkCreatedByUser = blocks => {
  blocks |> calculateProperty(calculateSnarkWorkCount);
};

let getSnarkFeesCollected = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.data) => {
      Array.fold_left(
        (map, snarkJob: Types.NewBlock.snarkJobs) => {
          StringMap.update(
            snarkJob.prover,
            feeCount =>
              switch (feeCount) {
              | Some(feeCount) => Some(Int64.add(feeCount, snarkJob.fee))
              | None => Some(snarkJob.fee)
              },
            map,
          )
        },
        map,
        block.snarkJobs,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let max = (a, b) => {
  a > b ? a : b;
};

let getHighestSnarkFeeCollected = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.data) => {
      Array.fold_left(
        (map, snarkJob: Types.NewBlock.snarkJobs) => {
          StringMap.update(
            snarkJob.prover,
            feeCount =>
              switch (feeCount) {
              | Some(feeCount) => Some(max(feeCount, snarkJob.fee))
              | None => Some(snarkJob.fee)
              },
            map,
          )
        },
        map,
        block.snarkJobs,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let calculateTransactionsSentToAddress = (blocks, address) => {
  blocks
  |> Array.fold_left((map, block: Types.NewBlock.data) => {
       block.transactions.userCommands
       |> Array.fold_left(
            (map, userCommand: Types.NewBlock.userCommands) => {
              userCommand.toAccount.publicKey === address
                ? incrementMapValue(userCommand.fromAccount.publicKey, map)
                : map
            },
            map,
          )
     });
};

// Calculate users and metrics
let calculateAllUsers = metrics => {
  List.fold_left(
    StringMap.merge((_, _, _) => {Some()}),
    StringMap.empty,
    metrics,
  );
};

let calculateMetrics = blocks => {
  let blocksCreated = blocks |> getBlocksCreatedByUser;
  let transactionSent = blocks |> getTransactionSentByUser;
  let snarkWorkCreated = blocks |> getSnarkWorkCreatedByUser;
  let users = calculateAllUsers([blocksCreated, transactionSent]);
  let snarkFeesCollected = blocks |> getSnarkFeesCollected;
  let highestSnarkFeeCollected = blocks |> getHighestSnarkFeeCollected;

  StringMap.mapi(
    (key, _) =>
      {
        Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
        transactionSent: StringMap.find_opt(key, transactionSent),
        snarkWorkCreated: StringMap.find_opt(key, snarkWorkCreated),
        snarkFeesCollected: StringMap.find_opt(key, snarkFeesCollected),
        highestSnarkFeeCollected:
          StringMap.find_opt(key, highestSnarkFeeCollected),
      },
    users,
  );
};