let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

let files = blockDirectory |> Node.Fs.readdirSync;

let blocks =
  Array.map(
    file => {
      Node.Fs.readFileAsUtf8Sync(blockDirectory ++ file)
      |> Js.Json.parseExn
      |> Types.NewBlock.unsafeJSONToNewBlock
    },
    files,
  );

let results =
  blocks
  |> Challenges.handleMetrics([|
       BlocksCreated,
       TransactionsSent,
       SnarkWorkCreated,
     |]);