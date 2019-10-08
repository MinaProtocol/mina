module Metadata = {
  let getValue = (key, content) => {
    // Search inside of the area enclosed by `---` for
    // a line that starts with `key:` and capture everything
    // between the : and the end of the line.
    let re =
      Js.Re.fromStringWithFlags(
        {|^---(?:.|\n)*^|} ++ key ++ {|:(.*)\n(?:.|\n)*^---|},
        ~flags="m",
      );
    switch (Js.Re.exec_(re, content)) {
    | None => None
    | Some(result) =>
      let captures = Js.Re.captures(result);
      let opt = Js.Nullable.toOption(captures[1]);
      Belt.Option.map(opt, String.trim);
    };
  };

  let getRequiredValue = (key, content, path) =>
    switch (getValue(key, content)) {
    | None => failwith("Didn't provide " ++ key ++ " in " ++ path)
    | Some(s) => s
    };
};

module Child_process = {
  type env = {
    .
    "CODA_CDN_URL": string,
    "PATH": string,
  };
  type option;

  [@bs.obj]
  external option: (~env: env=?, ~encoding: string=?, unit) => option = "";

  [@bs.module "child_process"]
  external execSync: (string, option) => string = "execSync";
};

let load = path => {
  let html =
    Child_process.execSync(
      "pandoc " ++ "--filter src/filter.js " ++ path ++ " --mathjax",
      Child_process.option(
        ~env={
          "CODA_CDN_URL": Links.Cdn.prefix(),
          "PATH": Js_dict.unsafeGet(Node.Process.process##env, "PATH"),
        },
        ~encoding="utf-8",
        (),
      ),
    );
  let content = Node.Fs.readFileAsUtf8Sync(path);
  (html, content);
};

let suffix = ".markdown";
