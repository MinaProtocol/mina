let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

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

let results = blocks |> Metrics.calculateMetrics |> Sheets.uploadPoints;