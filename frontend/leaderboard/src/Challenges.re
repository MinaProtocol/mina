module StringMap = Map.Make(String);

let addPointsToUsersWithAtleastN =
    (getMetricValue, threshold, pointsToReward, metricsMap) => {
  StringMap.fold(
    (key, metric, map) => {
      switch (getMetricValue(metric)) {
      | Some(metricValue) =>
        metricValue >= threshold
          ? StringMap.add(key, pointsToReward, map) : map
      | None => map
      }
    },
    metricsMap,
    StringMap.empty,
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

let echoBotPublicKey = "4vsRCVNep7JaFhtySu6vZCjnArvoAhkRscTy5TQsGTsKM4tJcYVc3uNUMRxQZAwVzSvkHDGWBmvhFpmCeiPASGnByXqvKzmHt4aR5uAWAQf3kqhwDJ2ZY3Hw4Dzo6awnJkxY338GEp12LE4x";

let metricsMap = blocks => {
  let blocksCreated = blocks |> getBlocksCreatedByUser;
  let transactionSent = blocks |> getTransactionSentByUser;
  let snarkWorkCreated = blocks |> getSnarkWorkCreatedByUser;
  let users = calculateAllUsers([blocksCreated, transactionSent]);
  let snarkFeesCollected = blocks |> getSnarkFeesCollected;
  let highestSnarkFeeCollected = blocks |> getHighestSnarkFeeCollected;
  let transactionsReceivedByEcho =
    calculateTransactionsSentToAddress(blocks, echoBotPublicKey);
  StringMap.mapi(
    (key, _) =>
      {
        Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
        transactionSent: StringMap.find_opt(key, transactionSent),
        snarkWorkCreated: StringMap.find_opt(key, snarkWorkCreated),
        snarkFeesCollected: StringMap.find_opt(key, snarkFeesCollected),
        highestSnarkFeeCollected:
          StringMap.find_opt(key, highestSnarkFeeCollected),
        transactionsReceivedByEcho:
          StringMap.find_opt(key, transactionsReceivedByEcho),
      },
    users,
  );
};

// Awards x points for top N
let applyTopNPoints = (n, pointsToGive, metricsMap, getMetricValue) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compare(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };
  Array.sort(f, metricsArray);
  let topNArray =
    Array.sub(metricsArray, 0, min(n, Array.length(metricsArray)));
  let topNArrayWithPoints =
    Array.map(((user, _)) => {(user, pointsToGive)}, topNArray);

  Array.fold_left(
    (map, (userPublicKey, userPoints)) => {
      StringMap.add(userPublicKey, userPoints, map)
    },
    StringMap.empty,
    topNArrayWithPoints,
  );
  
let calculatePoints = metricsMap => {
  // Get 500 pts if you send txn to the echo service
  let echoTransactionPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.transactionsReceivedByEcho,
      1,
      500,
      metricsMap,
    );

  //Earn 3 fees by producing and selling zk-SNARKs on the snarketplace: 1000 pts*
  let zkSnark3FeesPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      3L,
      1000,
      metricsMap,
    );

  //Anyone who earned 50 fees will be rewarded with an additional 1000 pts
  let zkSnark50FeesPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      50L,
      1000,
      metricsMap,
    );

  // Producing at least 3 blocks will earn an additional 1000 pts
  let blocksCreatedPoints =
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.blocksCreated,
      3,
      1000,
      metricsMap,
    );
  ();
};