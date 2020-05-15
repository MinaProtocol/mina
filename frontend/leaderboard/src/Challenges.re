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