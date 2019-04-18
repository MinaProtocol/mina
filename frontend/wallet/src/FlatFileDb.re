open Tc;

module Fs = {
  [@bs.val] [@bs.module "fs"]
  external readFile:
    (
      string,
      string,
      (Js.Nullable.t(Js.Exn.t), Js.Nullable.t(string)) => unit
    ) =>
    unit =
    "";

  [@bs.val] [@bs.module "fs"]
  external writeFile:
    (string, string, string, Js.Nullable.t(Js.Exn.t) => unit) => unit =
    "";

  let readFileAsync = path => Task.uncallbackify(readFile(path, "utf-8"));

  let writeFileAsync = (path, data) =>
    Task.uncallbackify0(writeFile(path, data, "utf-8"));
};

exception Json_parse_error;

type t = Js.Json.t;

let load = path => {
  Fs.readFileAsync(ProjectRoot.path ++ "/" ++ path)
  |> Task.mapError(~f=e => `Error_reading_file(e))
  |> Task.andThen(~f=contents =>
       switch (Json.parse(contents)) {
       | Some(json) => Task.succeed(json)
       | None => Task.fail(`Json_parse_error)
       }
     );
};

let store = (path, t) =>
  Fs.writeFileAsync(ProjectRoot.path ++ "/" ++ path, Js.Json.stringify(t))
  |> Task.mapError(~f=e => `Js_exn(e));
