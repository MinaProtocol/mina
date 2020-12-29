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
       1000,
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

let bonusSnarkFeeChallenge = metricsMap => {
  // Sum all snark fees recorded thus far
  let snarkFeeCounter =
    StringMap.fold(
      (_, metric: Types.Metrics.t, metricCounter) => {
        switch (metric.snarkFeesCollected) {
        | Some(metricValue) => Int64.add(metricCounter, metricValue)
        | None => metricCounter
        }
      },
      metricsMap,
      Int64.zero,
    );

  // If the metric value sum is greater than the threshold (3000 minas), every user that particpated will receive points
  snarkFeeCounter >= 3000000000000L
    ? StringMap.fold(
        (key, metric: Types.Metrics.t, map) => {
          switch (metric.snarkFeesCollected) {
          | Some(metricValue) =>
            metricValue >= Int64.zero ? StringMap.add(key, 2000, map) : map
          | None => map
          }
        },
        metricsMap,
        StringMap.empty,
      )
    : StringMap.empty;
};

let snarkFeeChallenge = metricsMap => {
  [
    Points.applyTopNPoints(
      [|
        (0, 6500), // 1st place: 8500 pts
        (1, 5000), // 2nd place: 7000 pts
        (2, 4000), // 3rd place: 6000 pts
        (51, 3000), // Top 50: 5000 pts.
        (251, 1500), // Top 250: 4000 pts
        (501, 1500), // Top 500: 3000 pts
        (1001, 1000) // Top 1000: 2000 pts
      |],
      metricsMap,
      (metricRecord: Types.Metrics.t) => metricRecord.snarkFeesCollected,
      compare,
    ),
    bonusSnarkFeeChallenge(metricsMap),
  ]
  |> Points.sumPointsMaps;
};

let bonusBlocksChallenge = metricsMap => {
  Points.applyTopNPoints(
    [|
      (0, 6500), // 1st place: 6500 pts
      (1, 5000), // 2nd place: 5000 pts
      (2, 4000), // 3rd place: 4000 pts
      (51, 3000), // Top 50: 3500 pts.
      (101, 3000), // Top 100: 3000 pts
      (401, 2000), // Top 400: 2000 pts
      (751, 1000) // Top 750: 1000 pts
    |],
    metricsMap,
    (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
    compare,
  );
};

let blocksChallenge = metricsMap => {
  [
    // Produce 1 block and get them accepted for 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      1,
      1000,
      metricsMap,
    ),
    // Anyone who produces at least 2 blocks will earn an additional 1000 pts.
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      2,
      1000,
      metricsMap,
    ),
    // For every next block you produce (after 2 blocks), you will earn 800 pts*.
    Points.addPointsForExtra(
      (metricRecord: Types.Metrics.t) => metricRecord.blocksCreated,
      2,
      100,
      metricsMap,
    ),
    bonusBlocksChallenge(metricsMap),
  ]
  |> Points.sumPointsMaps;
};

let sendMinaChallenge = metricsMap => {
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
    // Sent 500 transactions: 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      500,
      1000,
      metricsMap,
    ),
    // Sent 5000 transactions: 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      5000,
      1000,
      metricsMap,
    ),
    // Sent 10000 transactions: 1000 pts
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      10000,
      1000,
      metricsMap,
    ),
    Points.applyTopNPoints(
      [|
        (0, 5500), // 1st place: 5500 pts
        (1, 4000), // 2nd place: 4000 pts
        (2, 3000), // 3rd place: 3000 pts
        (51, 2500), // Top 50: 2500 pts.
        (101, 2000), // Top 100: 2000 pts
        (401, 1000), // Top 400: 1500 pts
        (751, 1000) // Top 750: 1000 pts
      |],
      metricsMap,
      (metricRecord: Types.Metrics.t) => metricRecord.transactionSent,
      compare,
    ),
  ]
  |> Points.sumPointsMaps;
};

let createAndSendTokenChallenge = metricsMap => {
  [
    // you will receive 1000 pts for minting and sending your own token to another account
    Points.addPointsToUsersWithAtleastN(
      (metricRecord: Types.Metrics.t) => metricRecord.createAndSendToken,
      1,
      1000,
      metricsMap,
    ),
  ]
  |> Points.sumPointsMaps;
};

let calculatePoints = (challengeName, metricsMap) => {
  switch (String.lowercase_ascii(challengeName)) {
  | "produce blocks on mina" => Some(blocksChallenge(metricsMap))
  | "snarking on mina" => Some(snarkFeeChallenge(metricsMap))
  | "send mina" => Some(sendMinaChallenge(metricsMap))
  | _ => None
  };
};
