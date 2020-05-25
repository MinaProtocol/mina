let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

let clientCredentials =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/../../credentials.json";

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

let sheetsCredentials = () => {
  clientCredentials
  |> Node.Fs.readFileAsUtf8Sync
  |> Js.Json.parseExn
  |> Types.FileCredentials.unsafeJSONToFileCredentials;
};

let results =
  blocks
  |> Metrics.calculateMetrics
  |> Upload.uploadPoints(sheetsCredentials());