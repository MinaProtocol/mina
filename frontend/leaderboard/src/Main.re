/*
 Main.re is the entry point of the leaderboard project.

 Main.re has the responsibilities for querying the archive postgres database for
 all the blockchain data and parsing the rows into blocks.

 Additionally, Main.re expects to have the credentials, spreadsheet id, and postgres
 connection string available in the form of environment variables.  */

let getEnvOrFail = name =>
  switch (Js.Dict.get(Node.Process.process##env, name)) {
  | Some(value) => value
  | None => failwith({j|Couldn't find env var: `$name`|j})
  };

/* The Google Sheets API expects the credentials to be a local file instead of a parameter
       Thus, we set an environment variable indicating it's path.
   */
Node.Process.putEnvVar(
  "GOOGLE_APPLICATION_CREDENTIALS",
  "./google_sheets_credentials.json",
);

let spreadsheetId = getEnvOrFail("SPREADSHEET_ID");
let pgConnectionCurr = getEnvOrFail("PGCONN1");
let pgConnectionPrev = getEnvOrFail("PGCONN2");

let main = () => {
  let currPool = Postgres.createPool(pgConnectionCurr);
  let prevPool = Postgres.createPool(pgConnectionPrev);
  Js.log("First Query - In Progress");
  Postgres.makeQuery(prevPool, Postgres.getBlocks, result => {
    switch (result) {
    | Ok(prevBlocks) =>
      Js.log("First Query - Finished");
      Js.log("Second Query - In Progress");
      Postgres.makeQuery(currPool, Postgres.getBlocks, result => {
        switch (result) {
        | Ok(currBlocks) =>
          Js.log("Second Query - Finished");
          let blocks = Belt.Array.concat(prevBlocks, currBlocks);
          Js.log("Length of all blocks: ");
          Js.log(Array.length(blocks));

          Js.log("Metrics - In Progress");
          let metrics =
            blocks |> Types.Block.parseBlocks |> Metrics.calculateMetrics;
          Js.log("Metrics - Finished");

          UploadLeaderboardPoints.uploadChallengePoints(
            spreadsheetId,
            metrics,
            () => {
              UploadLeaderboardData.uploadUserProfileData(spreadsheetId);

              Postgres.makeQuery(currPool, Postgres.getBlockHeight, result => {
                switch (result) {
                | Ok(blockHeightQuery) =>
                  Belt.Option.(
                    Js.Json.(
                      blockHeightQuery[0]
                      ->decodeObject
                      ->flatMap(__x => Js.Dict.get(__x, "max"))
                      ->flatMap(decodeString)
                      ->mapWithDefault((), height => {
                          UploadLeaderboardData.uploadData(
                            spreadsheetId,
                            height,
                          )
                        })
                    )
                  );
                  Postgres.endPool(currPool);
                  Postgres.endPool(prevPool);
                | Error(error) => Js.log(error)
                }
              });
            },
          );

        | Error(error) => Js.log(error)
        }
      });

    | Error(error) => Js.log(error)
    }
  });
};

main();
