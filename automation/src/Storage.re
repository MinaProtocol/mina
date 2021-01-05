/**
 * Bindings to @google-cloud/storage
 */

type t;
type bucket;
type file = {name: string};

[@bs.module "@google-cloud/storage"] [@bs.new]
external create: unit => t = "Storage";

[@bs.send] external getBucket: (t, string) => bucket = "bucket";

[@bs.send]
external uploadFile: (bucket, string) => Js.Promise.t(unit) = "upload";

[@bs.send]
external getFiles: bucket => Js.Promise.t(array(array(file))) = "getFiles";

type saveOpts = {resumable: bool};
[@bs.send]
external save: (file, string, saveOpts, Js.Exn.t => unit) => unit = "save";

// Initialize our Storage client
let client = create();

// TODO: Load these from environment variables
let keypairBucket = "network-keypairs";
let keysetBucket = "network-keysets";

external promiseErrorToExn: Js.Promise.error => Js.Exn.t = "%identity";

let upload = (~bucket, ~filename) => {
  Js.log2("Upload started:", filename);
  client->getBucket(bucket)->uploadFile(filename)
  |> Js.Promise.then_(_ => {
       Js.log("Upload successful!");
       Js.Promise.resolve();
     })
  |> Js.Promise.catch(e => {
       switch (Js.Exn.message(e->promiseErrorToExn)) {
       | Some(msg) => Js.log2("Upload error:", msg)
       | None => Js.log("Unknown error while uploading file.")
       };
       Js.Promise.resolve();
     });
};

let list = (~bucket) => {
  client->getBucket(bucket)->getFiles
  |> Js.Promise.then_(response => {
       response[0] |> Array.map(file => file.name) |> Js.Promise.resolve
     })
  |> Js.Promise.catch(e => {
       switch (Js.Exn.message(e->promiseErrorToExn)) {
       | Some(msg) => Js.log2("Access error:", msg)
       | None => Js.log("Unknown error while listing files in bucket.")
       };
       Js.Promise.resolve([||]);
     });
};
