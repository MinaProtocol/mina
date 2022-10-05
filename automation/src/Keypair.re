module CodaSDK = O1labsClientSdk.CodaSDK;

type t = {
  publicKey: string,
  privateKey: string,
  nickname: option(string),
};

external fromJson: Js.Json.t => t = "%identity";

let filename = keypair =>
  Belt.Option.getWithDefault(keypair.nickname, keypair.publicKey);

/**
 * Generates a new keypair with an optional nickname
 */
let create = (~nickname: option(string)) => {
  let keys = CodaSDK.genKeys();
  {publicKey: keys.publicKey, privateKey: keys.privateKey, nickname};
};

/**
 * Writes the serialized keypair to disk.
 */
let write = keypair => {
  Cache.write(
    Cache.Keypair,
    ~filename=filename(keypair),
    keypair->Js.Json.stringifyAny->Belt.Option.getExn,
  );
};

/**
 * Attempts to load a keyset based on the name.
 */
let load = name => {
  open Node.Fs;
  let filename = Cache.keypairsDir ++ name;
  if (existsSync(filename)) {
    let raw = readFileSync(filename, `utf8);
    Some(Js.Json.parseExn(raw)->fromJson);
  } else {
    None;
  };
};

/**
 * Writes the serialized keypair to disk.
 */
let upload = keypair => {
  let filename = Cache.keypairsDir ++ filename(keypair);
  Storage.upload(~bucket=Storage.keypairBucket, ~filename)
  |> ignore;
};
