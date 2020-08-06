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

let echoServiceChallenge = metricsMap => {
  metricsMap
  |> Points.addPointsToUsersWithAtleastN(
       (metricRecord: Types.Metrics.t) =>
         metricRecord.transactionsReceivedByEcho,
       1,
       500,
     );
};

let coinbaseReceiverChallenge = (points, metricsMap) => {
  metricsMap
  |> StringMap.fold(
       (key, metric: Types.Metrics.t, map) => {
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
  Points.applyTopNPoints(
    [|
      (0, 5500), // 1st place: 5500 pts
      (1, 4000), // 2nd place: 4000 pts
      (2, 3000), // 3rd place: 3000 pts
      (11, 2000), // Top 10: 2000 pts.
      (26, 1500), // Top 25: 1500 pts
      (101, 1000) // Top 100: 1000 pts
    |],
    metricsMap,
    (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
    compare,
  );
};

let blocksChallenge = metricsMap => {
  [
    // Produce 1 block and get them accepted in the main chain for 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      1,
      1000,
      metricsMap,
    ),
    // Anyone who produces at least 3 blocks will earn an additional 1000 pts.
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      3,
      1000,
      metricsMap,
    ),
    // For every next block you produce, you will earn 100 pts*.
    Points.addPointsForExtra(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      3,
      100,
      metricsMap,
    ),
    bonusBlocksChallenge(metricsMap),
  ]
  |> Points.sumPointsMaps;
};

let bonusSendCodaChallenge = metricsMap => {
  Points.applyTopNPoints(
    [|
      (0, 5500), // 1st place: 5500 pts
      (1, 4000), // 2nd place: 4000 pts
      (2, 3000), // 3rd place: 3000 pts
      (11, 2000), // Top 10: 2000 pts.
      (26, 1500), // Top 25: 1500 pts
      (101, 1000) // Top 100: 1000 pts
    |],
    metricsMap,
    (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
    compare,
  );
};

let sendCodaChallenge = metricsMap => {
  [
    // Sent 5 transactions: 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      5,
      1000,
      metricsMap,
    ),
    // Sent 50 transactions: 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      50,
      1000,
      metricsMap,
    ),
    bonusSendCodaChallenge(metricsMap),
  ]
  |> Points.sumPointsMaps;
};

let createAndSendTokenChallenge = metricsMap => {
  [
    // you will receive 500 pts* for minting and sending your own token to another account
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.createAndSendToken,
      1,
      500,
      metricsMap,
    ),
  ]
  |> Points.sumPointsMaps;
};

let calculatePoints = (challengeName, metricsMap) => {
  switch (String.lowercase_ascii(challengeName)) {
  | "stake your coda and produce blocks" => Some(blocksChallenge(metricsMap))
  | "send Coda tokens elsewhere" => Some(sendCodaChallenge(metricsMap))
  | "connect to testnet and send coda" =>
    Some(echoServiceChallenge(metricsMap))
  | "create and send fun tokens elsewhere" =>
    Some(createAndSendTokenChallenge(metricsMap))
  | _ => None
  };
};
