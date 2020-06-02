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

let applyTopNPoints = (n, points, metricsMap, getMetricValue) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compare(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };

  Array.sort(f, metricsArray);
  Belt.Array.reverseInPlace(metricsArray);

  let topNArray =
    Array.sub(metricsArray, 0, min(n, Array.length(metricsArray)));
  let topNArrayWithPoints =
    Array.map(((user, _)) => {(user, points)}, topNArray);
  Array.fold_left(
    (map, (userPublicKey, userPoints)) => {
      StringMap.add(userPublicKey, userPoints, map)
    },
    StringMap.empty,
    topNArrayWithPoints,
  );
};

let applyPointsToRange = (start, end_, points, metricsMap, getMetricValue) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compare(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };

  Array.sort(f, metricsArray);
  Belt.Array.reverseInPlace(metricsArray);

  let topNArrayWithPoints =
    metricsArray
    |> Js.Array.slice(~start, ~end_)
    |> Array.map(((user, _)) => {(user, points)});

  Array.fold_left(
    (map, (userPublicKey, userPoints)) => {
      StringMap.add(userPublicKey, userPoints, map)
    },
    StringMap.empty,
    topNArrayWithPoints,
  );
};

let applyNPlacePoints = (place, points, metricsMap, getMetricValue) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compare(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };

  Array.sort(f, metricsArray);
  Belt.Array.reverseInPlace(metricsArray);

  if (place < Array.length(metricsArray)) {
    let (username, _) = metricsArray[place];
    StringMap.empty |> StringMap.add(username, points);
  } else {
    StringMap.empty;
  };
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

let calcEchoServiceTimedChallenge = metricsMap => {
  addPointsToUsersWithAtleastN(
    (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.transactionsReceivedByEcho,
    1,
    500,
    metricsMap,
  );
};

let bonusBlocksChallenge = metricsMap => {
  [
    // Top 100: 1000 pts
    applyPointsToRange(
      26, 101, 1000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
    // Top 25: 1500 pts
    applyPointsToRange(
      11, 26, 1500, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
    // Top 10: 2000 pts
    applyPointsToRange(
      3, 11, 2000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
    // 3rd place: 3000 pts
    applyNPlacePoints(
      2, 3000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
    // 2nd place: 4000 pts
    applyNPlacePoints(
      1, 4000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
    // 1st place: 5500 pts
    applyNPlacePoints(
      0, 5500, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.blocksCreated
    ),
  ]
  |> sumPointsMaps;
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
    // Top 100: 1000 pts
    applyPointsToRange(
      26, 101, 1000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
    // Top 25: 1500 pts
    applyPointsToRange(
      11, 26, 1500, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
    // Top 10: 2000 pts
    applyPointsToRange(
      3, 11, 2000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
    // 3rd place: 3000 pts
    applyNPlacePoints(
      2, 3000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
    // 2nd place: 4000 pts
    applyNPlacePoints(
      1, 4000, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
    // 1st place: 5500 pts
    applyNPlacePoints(
      0, 5500, metricsMap, (metricRecord: Types.Metrics.metricRecord) =>
      metricRecord.snarkWorkCreated
    ),
  ]
  |> sumPointsMaps;
};

let zkSnarksChallenge = metricsMap => {
  [
    // Earn 3 fees by producing and selling zk-SNARKs on the snarketplace: 1000 pts
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkWorkCreated,
      3,
      1000,
      metricsMap,
    ),
    // Anyone who earned 50 fees will be rewarded with an additional 1000 pts.
    addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.metricRecord) =>
        metricRecord.snarkWorkCreated,
      50,
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
    | "Connect to testnet and send coda to another testnet user " =>
      Some(calcEchoServiceTimedChallenge(metricsMap))
    | _ => None
    }
  | None => None
  };
};