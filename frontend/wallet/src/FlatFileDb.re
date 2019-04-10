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

  let readFileAsync = path =>
    Task.Result.uncallbackify(readFile(path, "utf-8"));

  let writeFileAsync = (path, data) =>
    Task.Result.uncallbackify0(writeFile(path, data, "utf-8"));
};

type t = Js.Json.t;

let load = () => {
  Task.Result.Infix.
    // for now we'll just infix monad until we do the ppx
    (
      Fs.readFileAsync(ProjectRoot.path ++ "/db.json")
      >>| (contents => Js.Json.parseExn(contents))
    );
};

let store = t =>
  Fs.writeFileAsync(ProjectRoot.path ++ "/db.json", Js.Json.stringify(t));
