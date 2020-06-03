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
    |> Array.map(((username, _)) =>
         if (counter^ >= Array.length(threshholdPointsList)) {
           [|(username, 0)|];
         } else {
           let (place, points) = threshholdPointsList[counter^];
           if (place == counter^) {
             counter := counter^ + 1;
             [|(username, points)|];
           } else {
             let result =
               Js.Array.slice(~start=counter^, ~end_=place, metricsArray)
               |> Array.map(((username, _)) => {(username, points)});
             counter := place;
             result;
           };
         }
       )
    |> Array.to_list
    |> Array.concat;

  Belt.Array.keep(topNArrayWithPoints, ((_, points)) => {points !== 0})
  |> Array.fold_left(
       (map, (userPublicKey, userPoints)) => {
         StringMap.add(userPublicKey, userPoints, map)
       },
       StringMap.empty,
     );
};

// Combines two maps of users to points and returns one map of users to points
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

let calcEchoServiceChallenge = metricsMap => {
  addPointsToUsersWithAtleastN(
    (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.transactionsReceivedByEcho,
    1,
    500,
    metricsMap,
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
    switch (res[1]) {
    | "Stake your Coda and produce blocks" =>
      Some(blocksChallenge(metricsMap))
    | "Create and sell zk-SNARKs on Coda" =>
      Some(zkSnarksChallenge(metricsMap))
    | "Connect to testnet and send coda to another testnet user" =>
      Some(calcEchoServiceChallenge(metricsMap))
    | _ => None
    }
  | None => None
  };
};