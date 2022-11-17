/*
  Metrics.re has the responsibilities of making all the necessary queries to
  the archive node to gather user metrics on testnet challenges and transforming
  that data into a map of public_keys to metricRecord types.
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
    (users, zkAppDeployed) => {
  let usersMap =
    Array.fold_left(
      (map, user) => {StringMap.add(user, (), map)},
      StringMap.empty,
      users,
    );

  usersMap
  |> StringMap.filter((key, _) => {!List.mem(key, excludePublicKeys)})
  |> StringMap.mapi((key, _) =>
       {
         Types.Metrics.appsDeployed: StringMap.find_opt(key, zkAppDeployed)
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

  let zkAppDeployedChallange =
    getPromisifiedChallenge(
      users,
      pgPool,
      Postgres.getZkAppDeployedChallenge,
      0,
      "count",
    )
    |> filterNonePromises;


  [|zkAppDeployedChallange|]
  |> all
  |> then_(result => {
       result
       |> all
       |> then_(result => {
            users
            |> then_(users => {
                 let zkAppDeployedMetrics = result[0];

                 let zkAppDeployed =
                   convertDBRowsToMap(zkAppDeployedMetrics, int_of_string);

                 Js.log("Computing Metrics - In Progress");

                 let metrics =
                   calculateMetrics(
                     users,
                     zkAppDeployed
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
