/*
 Main.re is the entry point of the leaderboard project.

 Main.re has the responsibilities for querying the archive postgres database for
 all the blockchain data and parsing the rows into blocks.

 Additionally, Main.re expects to have the credentials, spreadsheet id, and postgres
 connection string available in the form of environment variables.  */

let getEnvOrFail = name =>
  switch (Js.Dict.get(Node.Process.process##env, name)) {
  | Some(value) => value
  | None => failwith({j|Couldn't find env var: `$name`"|j})
  };

let credentials = getEnvOrFail("GOOGLE_APPLICATION_CREDENTIALS");
let spreadsheetId = getEnvOrFail("SPREADSHEET_ID");
let pgConn = getEnvOrFail("PGCONN");

/* The Google Sheets API expects the credentials to be a local file instead of a parameter */
Node.Fs.writeFileAsUtf8Sync("./google_sheets_credentials.json", credentials);
Node.Process.putEnvVar(
  "GOOGLE_APPLICATION_CREDENTIALS",
  "./google_sheets_credentials.json",
);

let main = () => {
  let pool = Postgres.createPool(pgConn);
  Postgres.makeQuery(pool, Postgres.getBlocks, result => {
    switch (result) {
    | Ok(blocks) =>
      Types.Block.parseBlocks(blocks)
      |> Metrics.calculateMetrics
      |> UploadLeaderboardPoints.uploadChallengePoints(spreadsheetId);

      UploadLeaderboardData.uploadData(
        spreadsheetId,
        blocks |> Array.length |> string_of_int,
      );

      UploadLeaderboardData.uploadUserProfileData(spreadsheetId);
    | Error(error) => Js.log(error)
    }
  });
  Postgres.endPool(pool);
};

main();
