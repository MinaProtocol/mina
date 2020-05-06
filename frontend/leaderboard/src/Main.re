module NewBlock = {
  type stateHash = {stateHash: string};
  type newBlock = {newBlock: stateHash};
  type t = {data: newBlock};
};

external unsafeJSONToNewBlock: Js.Json.t => NewBlock.t = "%identity";

let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/src/blocks/";

let files = Node.Fs.readdirSync(blockDirectory);

Array.iter(
  _file => {
    let fileContents = Node.Fs.readFileAsUtf8Sync(blockDirectory ++ _file);
    let blockDataJson = Js.Json.parseExn(fileContents);
    let newBlock = unsafeJSONToNewBlock(blockDataJson);
    print_endline(newBlock.data.newBlock.stateHash);
  },
  files,
);