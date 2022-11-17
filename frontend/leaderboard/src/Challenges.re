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

let appsDeployed = metricsMap => {
  Js.log("appsDeployed Tracking");
  Points.applyTopNPoints(
    [|
      (0, 1000), // 1st place: 6500 pts
      (1, 1000), // 2nd place: 5000 pts
      (2, 1000), // 3rd place: 4000 pts
      (51, 1000), // Top 50: 3500 pts.
      (101, 1000), // Top 100: 3000 pts
      (251, 1000), // Top 250: 2000 pts
      (501, 1000), // Top 500: 1000 pts
      (751, 1000), // Top 750: 750 pts
      (1001, 1000) // Top 1000: 500 pts
    |],
    metricsMap,
    (metricRecord: Types.Metrics.t) => metricRecord.appsDeployed,
    compare,
  );
};

let calculatePoints = (challengeName, metricsMap) => {
  switch (String.lowercase_ascii(challengeName)) {
  | "deploy zkApp on mina" => Some(appsDeployed(metricsMap))
  | _ => None
  };
};
