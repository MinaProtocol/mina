let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

let files = blockDirectory |> Node.Fs.readdirSync;

let blocks =
  Array.map(
    _file => {
      Node.Fs.readFileAsUtf8Sync(blockDirectory ++ _file)
      |> Js.Json.parseExn
      |> Types.NewBlock.unsafeJSONToNewBlock
    },
    files,
  );

let results = Challanges.handleMetrics([|TransactionsSent|], blocks);