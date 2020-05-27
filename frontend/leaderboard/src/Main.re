let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

[@bs.val]
external credentials: string = "process.env.GOOGLE_APPLICATION_CREDENTIALS";

let files = blockDirectory |> Node.Fs.readdirSync;

let blocks =
  Array.map(
    file => {
      let fileContents = Node.Fs.readFileAsUtf8Sync(blockDirectory ++ file);
      let blockData = Js.Json.parseExn(fileContents);
      let block = Types.NewBlock.unsafeJSONToNewBlock(blockData);
      block.data.newBlock;
    },
    files,
  );

let setSheetsCredentials = () => {
  switch (Js.Types.classify(credentials)) {
  | JSString(validCredentials) =>
    Node.Fs.writeFileAsUtf8Sync(
      "./google_sheets_credentials.json",
      validCredentials,
    );
    Node.Process.putEnvVar(
      "GOOGLE_APPLICATION_CREDENTIALS",
      "./google_sheets_credentials.json",
    );
    Ok();
  | _ => Error("Invalid environment variable")
  };
};

let main = () => {
  switch (setSheetsCredentials()) {
  | Ok () => blocks |> Metrics.calculateMetrics |> Upload.uploadPoints
  | Error(error) => failwith(error)
  };
};

main();