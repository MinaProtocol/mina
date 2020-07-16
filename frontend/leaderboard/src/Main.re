/*
  Main.re is the entry point of the leaderboard project.

  Main.re has the responsibilities for reading in a directory of blocks and
  packing it up to be handed to Metrics.re. Blocks are defined in a json format.
  The parsed fields for blocks are defined in Types/NewBlock.

  Additionally, Main.re expects to have the credentials and spreadsheet id
  available in the form of environment variables. If no blocks are found,
  the execution fails and reports an error.
 */

let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

[@bs.val]
external credentials: Js.Undefined.t(string) =
  "process.env.GOOGLE_APPLICATION_CREDENTIALS";

[@bs.val]
external spreadsheetId: Js.Undefined.t(string) = "process.env.SPREADSHEET_ID";

let blocks =
  blockDirectory
  |> Node.Fs.readdirSync
  |> Array.map(file => {
       let fileContents = Node.Fs.readFileAsUtf8Sync(blockDirectory ++ file);
       let blockData = Js.Json.parseExn(fileContents);
       let block = Types.NewBlock.unsafeJSONToNewBlock(blockData);
       block.data.newBlock;
     });

let totalBlocks =
  blockDirectory |> Node.Fs.readdirSync |> Array.length |> string_of_int;

let setSheetsCredentials = () => {
  switch (
    Js.undefinedToOption(credentials),
    Js.undefinedToOption(spreadsheetId),
  ) {
  | (Some(validCredentials), Some(spreadsheetId)) =>
    Node.Fs.writeFileAsUtf8Sync(
      "./google_sheets_credentials.json",
      validCredentials,
    );
    Node.Process.putEnvVar(
      "GOOGLE_APPLICATION_CREDENTIALS",
      "./google_sheets_credentials.json",
    );
    Ok(spreadsheetId);
  | (None, _) => Error("Invalid credentials environment variable")
  | (_, None) => Error("Invalid spreadsheet environment variable")
  };
};

let main = () => {
  switch (setSheetsCredentials()) {
  | Ok(spreadsheetId) =>
    blocks
    |> Metrics.calculateMetrics
    |> UploadLeaderboardPoints.uploadChallengePoints(spreadsheetId);

    UploadLeaderboardData.uploadData(spreadsheetId, totalBlocks);

    UploadLeaderboardData.uploadUserProfileData(spreadsheetId);
  | Error(error) => failwith(error)
  };
};

main();
