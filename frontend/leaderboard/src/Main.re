type newBlock = {protocolState: string};

external unsafeJSONToNewBlock: Js.Json.t => newBlock = "%identity";

let files = Node.Fs.readdirSync("blocks");
Array.iter(
  _file => {
    let fileContents = Node.Fs.readFileAsUtf8Sync("block.json");
    let blockDataJson = Js.Json.parseExn(fileContents);
    let newBlock = unsafeJSONToNewBlock(blockDataJson);
    print_endline(newBlock.protocolState);
  },
  files,
);
