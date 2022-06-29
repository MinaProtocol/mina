// Each entry consists of a publicKey and an optional nickname
type entry = {
  publicKey: string,
  nickname: option(string),
};

type t = {
  name: string,
  entries: array(entry),
};

external fromJson: Js.Json.t => t = "%identity";

type actions =
  | Create
  | Add
  | Remove
  | List
  | Upload;

/**
 * Returns a new empty keyset.
 */
let create = name => {name, entries: [||]};

let stringify = keyset => keyset->Js.Json.stringifyAny->Belt.Option.getExn;

/**
 * Writes a keyset to disk.
 */
let write = keyset => {
  let filename = keyset.name;
  Cache.write(Cache.Keyset, ~filename, stringify(keyset));
};

/**
 * Attempts to load a keyset based on the name.
 */
let load = name => {
  open Node.Fs;
  let filename = Cache.keysetsDir ++ name;
  if (existsSync(filename)) {
    let raw = readFileSync(filename, `utf8);
    Some(Js.Json.parseExn(raw)->fromJson);
  } else {
    None;
  };
};

/**
 * Adds a publicKey to a keyset with an optional nickname.
 */
let append = (keyset, ~publicKey, ~nickname) => {
  {
    name: keyset.name,
    entries: Array.append([|{publicKey, nickname}|], keyset.entries),
  };
};

/**
 * Adds a keypair to a keyset based on it's publicKey.
 */
let appendKeypair: (t, Keypair.t) => t =
  (keyset, keypair) =>
    append(keyset, ~publicKey=keypair.publicKey, ~nickname=keypair.nickname);

/**
 * Uploads a serialized keyset to Storage.
 */
let upload = keyset => {
  let filename = Cache.keysetsDir ++ keyset.name;
  Storage.upload(~bucket=Storage.keysetBucket, ~filename) |> ignore;

  Array.map(
    entry => {
      let kpName =
        Belt.Option.getWithDefault(entry.nickname, entry.publicKey);
      switch (Keypair.load(kpName)) {
      | Some(keypair) => Keypair.upload(keypair)
      | None => ()
      };
    },
    keyset.entries,
  );
};

type listResponse = {
  remote: array(string),
  local: array(string),
};

/**
 * Returns a Promise that resolves with a list of all keyset names.
 */
let list = () => {
  Storage.list(~bucket=Storage.keysetBucket)
  |> Js.Promise.then_(remote => {
       let local = Cache.list(Cache.Keyset);
       Js.Promise.resolve({remote, local});
     });
};
