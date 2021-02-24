/*
 Main.re is the entry point of the leaderboard project.

 Main.re has the responsibilities of being the driver to upload all necessary
 information to the google sheets.

 Additionally, Main.re expects to have the  spreadsheet id, and postgres
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
let pgConnection = getEnvOrFail("PGCONN");

let main = () => {
  open Js.Promise;
  let pool = Postgres.createPool(pgConnection);

  Metrics.calculateMetricsAndUploadPoints(pool, spreadsheetId)
  |> then_(_ => {
       Postgres.makeQuery(pool, Postgres.getBlockHeight)
       |> then_(blockHeight => {
            switch (Postgres.getRow(blockHeight, "max", 0)) {
            | Some(height) =>
              UploadLeaderboardData.uploadData(spreadsheetId, height)
            | None => ()
            };
            resolve();
          })
       |> then_(_ => {
            UploadLeaderboardData.uploadUserProfileData(spreadsheetId);
            resolve();
          })
       |> then_(_ => {
            Postgres.endPool(pool);
            resolve();
          })
       |> ignore;
       resolve();
     });
};

main();
