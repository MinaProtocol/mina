/*
  Metrics.re has the responsibilities of making all the necessary queries to
  the archive node to gather user metrics on testnet challenges and transforming
  that data into a map of public_keys to metricRecord types.

  The data visualized for a Map is as follows, where x is some int value:

 "public_key1": {
    blocksCreated: x,
    transactionSent: x,
    snarkFeesCollected: x,
    highestSnarkFeeCollected: x,
    transactionsReceivedByEcho: x,
    coinbaseReceiver: x,
    createAndSendToken: x,
 }

  All the metrics to be computed are specified in calculateMetrics(). Each
  metric to be computed is contained within it's own Map structure and is then
  combined together with all other metric Maps.
 */

module StringMap = Map.Make(String);

let echoBotPublicKeys = [
  "B62qndJi5mnRoBZ8SAYDM1oR2SgAk5WpZC8hGpJUZ4e64kDHGbFMeLJ",
];

let excludePublicKeys = [];

// Helper functions for gathering metrics
let printMap = map => {
  map
  |> StringMap.mapi((key, value) => {
       Js.log(key);
       Js.log(value);
     });
};

let convertDBRowsToMap = (a, f) => {
  a
  |> Array.fold_left(
       (map, info) => {StringMap.add(info[0], f(info[1]), map)},
       StringMap.empty,
     );
};

let mergeMetricsMaps = (metricMap, oldMetricMap, f) => {
  let oldMetricsMap =
    StringMap.mapi(
      (key, challengeMetric) =>
        if (StringMap.mem(key, metricMap)) {
          f(StringMap.find(key, metricMap), challengeMetric);
        } else {
          challengeMetric;
        },
      oldMetricMap,
    );

  StringMap.mapi(
    (key, challengeMetric) =>
      if (StringMap.mem(key, oldMetricsMap)) {
        StringMap.find(key, oldMetricsMap);
      } else {
        challengeMetric;
      },
    metricMap,
  );
};

let mergeIntMap = (challenges, challengesOld) => {
  let challengeMap = convertDBRowsToMap(challenges, int_of_string);
  let challengeMapOld = convertDBRowsToMap(challengesOld, int_of_string);
  mergeMetricsMaps(challengeMap, challengeMapOld, (a, b) => a + b);
};

let mergeInt64Map = (challenges, challengesOld) => {
  let challengeMap = convertDBRowsToMap(challenges, Int64.of_string);
  let challengeMapOld = convertDBRowsToMap(challengesOld, Int64.of_string);
  mergeMetricsMaps(challengeMap, challengeMapOld, Int64.add);
};

/**
 * Makes a query to the archive node for the specified challenge.
 * Returns a 2d array where the first column is the public keys of
 * users and the second column being the returned query data.
 *
 */
let getPromisifiedChallenge = (users, pgPool, f, index, columnName) => {
  Js.Promise.(
    users
    |> then_(users => {
         users
         |> Array.map(user => {
              Postgres.makeQuery(pgPool, f(user))
              |> then_(row => {
                   (
                     switch (Postgres.getRow(row, columnName, index)) {
                     | Some(dbResult) => Some([|user, dbResult|])
                     | None => None
                     }
                   )
                   |> resolve
                 })
            })
         |> resolve
       })
  );
};

let filterNonePromises = challenges => {
  Js.Promise.(
    challenges
    |> then_(challenge => {
         let result =
           challenge
           |> all
           |> then_(rows => {
                Array.fold_left(
                  (values, row) => {
                    switch (row) {
                    | Some(row) => Array.append(values, [|row|])
                    | None => values
                    }
                  },
                  [||],
                  rows,
                )
                |> resolve
              });
         resolve(result);
       })
  );
};

let calculateMetrics =
    (users, blocksChallenge, snarkChallenge, transactionChallenge) => {
  let usersMap =
    Array.fold_left(
      (map, user) => {StringMap.add(user, (), map)},
      StringMap.empty,
      users,
    );

  let highestSnarkFeeCollected = StringMap.empty;
  let transactionsReceivedByEcho = StringMap.empty;
  let coinbaseReceiverChallenge = StringMap.empty;

  usersMap
  |> StringMap.filter((key, _) => {!List.mem(key, excludePublicKeys)})
  |> StringMap.mapi((key, _) =>
       {
         Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksChallenge),
         transactionSent: StringMap.find_opt(key, transactionChallenge),
         snarkFeesCollected: StringMap.find_opt(key, snarkChallenge),
         highestSnarkFeeCollected:
           StringMap.find_opt(key, highestSnarkFeeCollected),
         transactionsReceivedByEcho:
           StringMap.find_opt(key, transactionsReceivedByEcho),
         coinbaseReceiver: StringMap.find_opt(key, coinbaseReceiverChallenge),
       }
     );
};

let calculateMetricsAndUploadPoints = (pgPool, spreadsheetId) => {
  open Js.Promise;
  let users =
    Postgres.makeQuery(pgPool, Postgres.getUsers)
    |> then_(userRows => {
         userRows
         |> Array.map(userRow => {
              switch (Postgres.getColumn(userRow, "value")) {
              | Some(pk) => pk
              | None => ""
              }
            })
         |> resolve
       });

  let blocksChallenge =
    getPromisifiedChallenge(
      users,
      pgPool,
      Postgres.getBlocksChallenge,
      0,
      "count",
    )
    |> filterNonePromises;

  let snarkFeeChallenge =
    getPromisifiedChallenge(
      users,
      pgPool,
      Postgres.getSnarkFeeChallenge,
      0,
      "sum",
    )
    |> filterNonePromises;

  let transactionSentChallenge =
    getPromisifiedChallenge(
      users,
      pgPool,
      Postgres.getTransactionsSentChallenge,
      0,
      "max",
    )
    |> filterNonePromises;

  [|blocksChallenge, snarkFeeChallenge, transactionSentChallenge|]
  |> all
  |> then_(result => {
       result
       |> all
       |> then_(result => {
            users
            |> then_(users => {
                 let blocksMetrics = result[0];
                 let snarkFeeMetrics = result[1];
                 let transactionMetrics = result[2];

                 let blocksChallenge =
                   convertDBRowsToMap(blocksMetrics, int_of_string);
                 let snarkFeeChallenge =
                   convertDBRowsToMap(snarkFeeMetrics, Int64.of_string);
                 let transactionChallenge =
                   convertDBRowsToMap(transactionMetrics, int_of_string);

                 Js.log("Computing Metrics - In Progress");

                 let metrics =
                   calculateMetrics(
                     users,
                     blocksChallenge,
                     snarkFeeChallenge,
                     transactionChallenge,
                   );

                 Js.log("Computing Metrics - Done");

                 UploadLeaderboardPoints.uploadChallengePoints(
                   spreadsheetId,
                   metrics,
                 );
                 resolve();
               })
            |> ignore;
            resolve();
          })
     });
};
