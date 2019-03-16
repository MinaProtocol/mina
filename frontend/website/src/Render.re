[@bs.module "emotion-server"]
external renderStylesToString: string => string = "";

type critical = {
  .
  "html": string,
  "css": string,
};

[@bs.module "emotion-server"]
external extractCritical: string => critical = "";

module Fs = {
  [@bs.val] [@bs.module "fs"]
  external mkdirSync:
    (
      string,
      {
        .
        "recursive": bool,
        "mode": int,
      }
    ) =>
    unit =
    "";

  [@bs.val] [@bs.module "fs"]
  external symlinkSync: (string, string) => unit = "";
};

module Rimraf = {
  [@bs.val] [@bs.module "rimraf"] external sync: string => unit = "";
};

let writeStatic = (path, rootComponent) => {
  let rendered =
    extractCritical(ReactDOMServerRe.renderToStaticMarkup(rootComponent));
  Node.Fs.writeFileAsUtf8Sync(
    path ++ ".html",
    "<!doctype html><meta charset=\"utf-8\" />\n" ++ rendered##html,
  );
  Node.Fs.writeFileAsUtf8Sync(path ++ ".css", rendered##css);
};

let load = path => {
  Node.Child_process.execSync(
    "pandoc " ++ path ++ " --mathjax",
    Node.Child_process.option(),
  );
};

let postSuffix = ".markdown";
let posts =
  Node.Fs.readdirSync("posts")
  |> Js.Array.filter(s => Js.String.endsWith(postSuffix, s))
  |> Array.map(fileName => {
       let length = String.length(fileName) - String.length(postSuffix);
       let name = String.sub(fileName, 0, length);
       let content = Node.Fs.readFileAsUtf8Sync("posts/" ++ fileName);
       let html = load("posts/" ++ fileName);
       (name, content, html);
     });

module Router = {
  type t =
    | File(string, ReasonReact.reactElement)
    | Dir(string, array(t));

  let generateStatic = {
    let rec helper = path =>
      fun
      | File(name, elem) => {
          writeStatic(path ++ "/" ++ name, elem);
        }
      | Dir(name, routes) => {
          let path_ = path ++ "/" ++ name;
          Fs.mkdirSync(path_, {"recursive": true, "mode": 0o755});
          routes |> Array.iter(helper(path_));
        };

    helper("./");
  };
};

// TODO: Render job pages
let jobOpenings = [|
  ("engineering-manager", "Engineering Manager (San Francisco)."),
  ("product-manager", "Product Manager (San Francisco)."),
  ("senior-frontend-engineer", "Senior Frontend Engineer (San Francisco)."),
  (
    "protocol-reliability-engineer",
    "Protocol Reliability Engineer (San Francisco).",
  ),
  ("protocol-engineer", "Senior Protocol Engineer (San Francisco)."),
|];

// GENERATE

Rimraf.sync("site");
Router.(
  generateStatic(
    Dir(
      "site",
      [|
        Dir(
          "blog",
          posts
          |> Array.map(((name, content, html)) =>
               File(
                 name,
                 <LegacyPage
                   extraHeaders=BlogPost.extraHeaders footerColor="bg-snow">
                   <BlogPost name content html />
                 </LegacyPage>,
               )
             ),
        ),
        File(
          "jobs",
          <LegacyPage extraHeaders=Careers.extraHeaders>
            <Careers jobOpenings />
          </LegacyPage>,
        ),
        File(
          "code",
          <LegacyPage extraHeaders=Code.extraHeaders> <Code /> </LegacyPage>,
        ),
      |],
    ),
  )
);
Fs.symlinkSync(
  Node.Process.cwd() ++ "/../../src/app/website/static",
  "./site/static",
);
