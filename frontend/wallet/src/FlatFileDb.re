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

type t = Js.Json.t;

let load = () => {
  Fs.readFileAsync(ProjectRoot.path ++ "/db.json")
  |> Task.map(~f=contents => Js.Json.parseExn(contents));
};

let store = t =>
  Fs.writeFileAsync(ProjectRoot.path ++ "/db.json", Js.Json.stringify(t));
