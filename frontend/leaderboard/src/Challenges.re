module StringMap = Map.Make(String);

// Helper functions for gathering metrics
let printMap = map => {
  StringMap.mapi(
    (key, value) => {
      Js.log(key);
      Js.log(Int64.to_string(value));
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
       | Some(valueCount) => Some(Int64.add(valueCount, Int64.one))
       | None => Some(Int64.one)
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
  Array.fold_left(
    (map, block: Types.NewBlock.data) => {
      block.transactions.userCommands
      |> Array.fold_left(
           (map, userCommand: Types.NewBlock.userCommands) => {
             userCommand.toAccount.publicKey === address
               ? incrementMapValue(userCommand.fromAccount.publicKey, map)
               : map
           },
           map,
         )
    },
    StringMap.empty,
    blocks,
  );
};

// Calculate users and metrics
let calculateAllUsers = metrics => {
  List.fold_left(
    StringMap.merge((_, _, _) => {Some()}),
    StringMap.empty,
    metrics,
  );
};

let addPointsToUsersWithAtleastN =
    (getMetricValue, threshold, pointsToReward, metricsMap) => {
  StringMap.fold(
    (key, metric, map) => {
      switch (getMetricValue(metric)) {
      | Some(metricValue) =>
        metricValue >= threshold
          ? StringMap.add(key, pointsToReward, map)
          : StringMap.add(key, Int64.zero, map)
      | None => StringMap.add(key, Int64.zero, map)
      }
    },
    metricsMap,
    StringMap.empty,
  );
};

let calculatePoints = metricsMap => {
  // Get 500 pts if you send txn to the echo service
  let echoTransactionPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.transactionsReceivedByEcho,
      1L,
      500L,
      metricsMap,
    );

  // Earn 3 fees by producing and selling zk-SNARKs on the snarketplace: 1000 pts*
  let zkSnark3FeesPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      3L,
      1000L,
      metricsMap,
    );

  // Anyone who earned 50 fees will be rewarded with an additional 1000 pts
  let zkSnark50FeesPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      50L,
      1000L,
      metricsMap,
    );

  // Producing at least 3 blocks will earn an additional 1000 pts
  let blocksCreatedPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.blocksCreated,
      3L,
      1000L,
      metricsMap,
    );
  ();
};

let echoBotPublicKey = "4vsRCVNep7JaFhtySu6vZCjnArvoAhkRscTy5TQsGTsKM4tJcYVc3uNUMRxQZAwVzSvkHDGWBmvhFpmCeiPASGnByXqvKzmHt4aR5uAWAQf3kqhwDJ2ZY3Hw4Dzo6awnJkxY338GEp12LE4x";
let calculateMetrics = blocks => {
  let blocksCreated = getBlocksCreatedByUser(blocks);
  let transactionSent = getTransactionSentByUser(blocks);
  let snarkWorkCreated = getSnarkWorkCreatedByUser(blocks);
  let snarkFeesCollected = getSnarkFeesCollected(blocks);
  let highestSnarkFeeCollected = getHighestSnarkFeeCollected(blocks);
  let transactionsReceivedByEcho =
    calculateTransactionsSentToAddress(blocks, echoBotPublicKey);

  calculateAllUsers([
    blocksCreated,
    transactionSent,
    snarkWorkCreated,
    snarkFeesCollected,
    highestSnarkFeeCollected,
    transactionsReceivedByEcho,
  ])
  |> StringMap.mapi((key, _) =>
       {
         Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
         transactionSent: StringMap.find_opt(key, transactionSent),
         snarkWorkCreated: StringMap.find_opt(key, snarkWorkCreated),
         snarkFeesCollected: StringMap.find_opt(key, snarkFeesCollected),
         highestSnarkFeeCollected:
           StringMap.find_opt(key, highestSnarkFeeCollected),
         transactionsReceivedByEcho:
           StringMap.find_opt(key, transactionsReceivedByEcho),
       }
     )
  |> calculatePoints;
};