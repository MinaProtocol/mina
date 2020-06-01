let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

[@bs.val]
external credentials: Js.Undefined.t(string) =
  "process.env.GOOGLE_APPLICATION_CREDENTIALS";

let blocks =
  blockDirectory
  |> Node.Fs.readdirSync
  |> Array.map(file => {
       let fileContents = Node.Fs.readFileAsUtf8Sync(blockDirectory ++ file);
       let blockData = Js.Json.parseExn(fileContents);
       let block = Types.NewBlock.unsafeJSONToNewBlock(blockData);
       block.data.newBlock;
     });

let setSheetsCredentials = () => {
  switch (Js.undefinedToOption(credentials)) {
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
  | None => Error("Invalid environment variable")
  };
};

let main = () => {
  switch (setSheetsCredentials()) {
  | Ok () => blocks |> Metrics.calculateMetrics |> Upload.uploadPoints
  | Error(error) => failwith(error)
  };
};

main();