/*
  Main.re is the entry point of the leaderboard project.

  Main.re has the responsibilities for reading in a directory of blocks and
  packing it up to be handed to Metrics.re. Blocks are defined in a json format.
  The parsed fields for blocks are defined in Types/NewBlock.

  Additionally, Main.re expects to have the credentials and spreadsheet id
  available in the form of environment variables. If no blocks are found,
  the execution fails and reports an error.
 */

let getEnvOrFail = name =>
  switch (Js.Dict.get(Node.Process.process##env, name)) {
  | Some(value) => value
  | None => failwith({j|Couldn't find env var: `$name`"|j})
  };

let getEnv = (~default, name) =>
  Js.Dict.get(Node.Process.process##env, name)
  ->Belt.Option.getWithDefault(default)
  ->Js.String.trim;

let getEnvOpt = name =>
  Js.Dict.get(Node.Process.process##env, name)
  ->Belt.Option.map(Js.String.trim);

let credentials = getEnvOpt("GOOGLE_APPLICATION_CREDENTIALS");
let spreadsheetId = getEnvOpt("SPREADSHEET_ID");
let pgConn = getEnvOpt("PGCONN");

let parseBlocks = blocks => {
  blocks |> Array.iter(blocks => Js.log(blocks));
};

let setSheetsCredentials = () => {
  switch (credentials) {
  | Some(validCredentials) =>
    Node.Fs.writeFileAsUtf8Sync(
      "./google_sheets_credentials.json",
      validCredentials,
    );
    Node.Process.putEnvVar(
      "GOOGLE_APPLICATION_CREDENTIALS",
      "./google_sheets_credentials.json",
    );
    Ok();
  | None => Error()
  };
};

let main = () => {
  switch (setSheetsCredentials()) {
  | Ok () =>
    let pool = Postgres.createPool(Belt.Option.getExn(pgConn));
    Postgres.makeQuery(pool, Postgres.getBlocks, result => {
      switch (result) {
      | Ok(blocks) => parseBlocks(blocks)
      | Error(error) => Js.log(error)
      }
    });
    ();
  | Error(_) => ()
  };
};

// blocks
// |> Metrics.calculateMetrics
// |> UploadLeaderboardPoints.uploadChallengePoints(spreadsheetId);
// UploadLeaderboardData.uploadData(spreadsheetId, totalBlocks);
//UploadLeaderboardData.uploadUserProfileData(spreadsheetId);

main();
