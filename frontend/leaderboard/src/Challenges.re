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

// Examples of using the challenges
let calculatePoints = (challengeID, metricsMap) => {
  switch (Js.String.match([%re "/\s*([a-zA-z\s*]+)\s*/"], challengeID)) {
  | Some(res) =>
    Js.log(res[1]);
    switch (res[1]) {
    | "Blocks" =>
      addPointsToUsersWithAtleastN(
        (metricRecord: Types.Metrics.metricRecord) =>
          metricRecord.blocksCreated,
        1,
        1000,
        metricsMap,
      )
    | "Snark Fees" =>
      addPointsToUsersWithAtleastN(
        (metricRecord: Types.Metrics.metricRecord) =>
          metricRecord.snarkFeesCollected,
        3L,
        1000,
        metricsMap,
      )
    | "Echo Transaction" =>
      addPointsToUsersWithAtleastN(
        (metricRecord: Types.Metrics.metricRecord) =>
          metricRecord.transactionsReceivedByEcho,
        1,
        500,
        metricsMap,
      )
    | _ => StringMap.empty
    };
  | None => StringMap.empty
  };
};