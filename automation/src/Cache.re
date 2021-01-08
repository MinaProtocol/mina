type model =
  | Keypair
  | Keyset
  | Genesis;

// TODO: Add support for ENV and non Unix environments
let baseDir = "./keys";
let keypairsDir = baseDir ++ "/keypairs/";
let keysetsDir = baseDir ++ "/keysets/";
let genesisDir = baseDir ++ "/genesis/";

let modelDir = model =>
  switch (model) {
  | Keypair => keypairsDir
  | Keyset => keysetsDir
  | Genesis => genesisDir
  };

[@bs.module "mkdirp"] external mkdirp: string => unit = "sync";

/**
 * Writes an arbitrary string to cache.
 */
let write = (model, ~filename, contents) => {
  let baseDir = modelDir(model);
  mkdirp(Node.Path.dirname(baseDir));

  let path = Node.Path.join2(baseDir, filename);
  try(Node.Fs.writeFileSync(path, contents, `utf8)) {
  | Js.Exn.Error(e) =>
    switch (Js.Exn.message(e)) {
    | Some(msg) => Js.log({j|Error: $msg|j})
    | None =>
      Js.log(
        {j|An unknown error occured while writing a keypair to $filename|j},
      )
    }
  };
};

/**
 * Lists all the entries for given model.
 */
let list = model => modelDir(model)->Node.Fs.readdirSync;
