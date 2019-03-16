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
    switch (Js.Re.exec(content, re)) {
    | None => None
    | Some(result) =>
      let captures = Js.Re.captures(result);
      let opt = Js.Nullable.toOption(captures[1]);
      Belt.Option.map(opt, String.trim);
    };
  };

  let getRequiredValue = (key, content, filename) =>
    switch (getValue(key, content)) {
    | None =>
      failwith("Didn't provide " ++ key ++ " in " ++ filename ++ ".markdown")
    | Some(s) => s
    };
};

let load = path => {
  let html =
    Node.Child_process.execSync(
      "pandoc " ++ path ++ " --mathjax",
      Node.Child_process.option(),
    );
  let content = Node.Fs.readFileAsUtf8Sync(path);
  (html, content);
};

let suffix = ".markdown";
