/*
  Challenges.re has the responsibilities of taking a Map of public keys to
  metricRecords and compute a new Map that contains a public key to
  points where points is a number value (either Int64 or int).

  Points are rewarded based on completing challenges that are previously defined
  by O(1) community managers. The challenges that are supported are defined in
  calculatePoints()

  The data visualized for a Map is as follows, where x is some number value:

  "public_key1": x

   All the challenges to be computed are specified in calculatePoints().
   calculatePoints() is invoked in Upload.re where the points are computed
   and then uploaded to the Leaderboard Google Sheets.
 */

module StringMap = Map.Make(String);

let addPointsToUsersWithAtleastN =
    (getMetricValue, threshold, points, metricsMap) => {
  StringMap.fold(
    (key, metric, map) => {
      switch (getMetricValue(metric)) {
      | Some(metricValue) =>
        metricValue >= threshold ? StringMap.add(key, points, map) : map
      | None => map
      }
    },
    metricsMap,
    StringMap.empty,
  );
};

let applyTopNPoints = (threshholdPointsList, metricsMap, getMetricValue) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compare(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };

  Array.sort(f, metricsArray);
  Belt.Array.reverseInPlace(metricsArray);

  let counter = ref(0);
  let topNArrayWithPoints =
    metricsArray
    |> Array.mapi((i, (username, _)) =>
         if (counter^ >= Array.length(threshholdPointsList)) {
           (username, 0);
         } else {
           let (place, points) = threshholdPointsList[counter^];
           if (place == i) {
             counter := counter^ + 1;
             (username, points);
           } else {
             (username, points);
           };
         }
       );

  Belt.Array.keep(topNArrayWithPoints, ((_, points)) => {points !== 0})
  |> Array.fold_left(
       (map, (userPublicKey, userPoints)) => {
         StringMap.add(userPublicKey, userPoints, map)
       },
       StringMap.empty,
     );
};

// Combines a list of maps of users to points and returns one map of users to points
let sumPointsMaps = maps => {
  maps
  |> List.fold_left(
       StringMap.merge((_, value, secondValue) => {
         switch (value, secondValue) {
         | (Some(value), Some(secondValue)) => Some(value + secondValue)
         | (Some(value), None)
         | (None, Some(value)) => Some(value)
         | (None, None) => None
         }
       }),
       StringMap.empty,
     );
};

let echoServiceChallenge = metricsMap => {
  metricsMap
  |> addPointsToUsersWithAtleastN(
       (metricRecord: Types.Metrics.metricRecord) =>
         metricRecord.transactionsReceivedByEcho,
       1,
       500,
     );
};

let coinbaseReceiverChallenge = (points, metricsMap) => {
  metricsMap
  |> StringMap.fold(
       (key, metric: Types.Metrics.metricRecord, map) => {
         switch (metric.coinbaseReceiver) {
         | Some(metricValue) =>
           metricValue ? StringMap.add(key, points, map) : map
         | None => map
         }
       },
       StringMap.empty,
     );
};

let bonusBlocksChallenge = metricsMap => {
  applyTopNPoints(
    [|
      (0, 5500), // 1st place: 5500 pts
      (1, 4000), // 2nd place: 4000 pts
      (2, 3000), // 3rd place: 3000 pts
      (11, 2000), // Top 10: 2000 pts.
      (26, 1500), // Top 25: 1500 pts
      (101, 1000) // Top 100: 1000 pts
    |],
    metricsMap,
    (metricRecord: Types.Metrics.metricRecord) =>
    metricRecord.blocksCreated
  );
};

let blocksChallenge = metricsMap => {
  [
    // Produce 1 block and get them accepted in the main chain for 1000 pts
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.blocksCreated,
      1,
      1000,
      metricsMap,
    ),
    // Anyone who produces at least 3 blocks will earn an additional 1000 pts.
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.blocksCreated,
      3,
      1000,
      metricsMap,
    ),
    bonusBlocksChallenge(metricsMap),
  ]
  |> sumPointsMaps;
};

let bonusZkSnarkChallenge = metricsMap => {
  [
    applyTopNPoints(
      [|
        (0, 5500), // 1st place: 5500 pts
        (1, 4000), // 2nd place: 4000 pts
        (2, 3000), // 3rd place: 3000 pts
        (11, 2000), // Top 10: 2000 pts.
        (26, 1500), // Top 25: 1500 pts
        (101, 1000) // Top 100: 1000 pts
      |],
      metricsMap,
      (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkFeesCollected
    ),
    //The user who sold the most expensive SNARK will receive a bonus of 500 pts
    applyTopNPoints(
      [|(0, 500)|], metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.highestSnarkFeeCollected
    ),
  ]
  |> sumPointsMaps;
};

let zkSnarksChallenge = metricsMap => {
  [
    // Earn 3 fees by producing and selling zk-SNARKs on the snarketplace: 1000 pts
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      3L,
      1000,
      metricsMap,
    ),
    // Anyone who earned 50 fees will be rewarded with an additional 1000 pts.
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkFeesCollected,
      50L,
      1000,
      metricsMap,
    ),
    bonusZkSnarkChallenge(metricsMap),
  ]
  |> sumPointsMaps;
};

let calculatePoints = (challengeID, metricsMap) => {
  // Regex grabs last string after a "Challenge #"
  switch (
    Js.String.match(
      [%re "/\s*([a-zA-z\s-*]+)\s*(?!.*\s*([a-zA-z\s-*]+)\s*)/"],
      challengeID,
    )
  ) {
  | Some(res) =>
    switch (String.lowercase_ascii(res[1])) {
    | "stake your coda and produce blocks" =>
      Some(blocksChallenge(metricsMap))
    | "create and sell zk-snarks on coda" =>
      Some(zkSnarksChallenge(metricsMap))
    | "connect to testnet and send coda" =>
      Some(echoServiceChallenge(metricsMap))
    | _ => None
    }
  | None => None
  };
};