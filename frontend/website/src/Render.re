[@bs.module "emotion-server"]
external renderStylesToString: string => string = "renderStylesToString";

type critical = {
  .
  "html": string,
  "css": string,
};

[@bs.module "emotion-server"]
external extractCritical: string => critical = "extractCritical";

module Rimraf = {
  [@bs.val] [@bs.module "rimraf"] external sync: string => unit = "sync";
};

Links.Cdn.setPrefix(
  Config.isProd ? "https://cdn.codaprotocol.com/website" : "",
);

Style.Typeface.load();

let writeStatic = (path, rootComponent) => {
  let rendered =
    extractCritical(ReactDOMServerRe.renderToStaticMarkup(rootComponent));
  Node.Fs.writeFileAsUtf8Sync(
    path ++ ".html",
    "<!doctype html>\n" ++ rendered##html,
  );
  Node.Fs.writeFileAsUtf8Sync(path ++ ".css", rendered##css);
};

let asset_regex = [%re {|/\/static\/blog\/.*{png,jpg,svg}/|}];

let posts =
  Node.Fs.readdirSync("posts")
  |> Array.to_list
  |> List.filter(s => Js.String.endsWith(Markdown.suffix, s))
  |> List.map(fileName => {
       let length = String.length(fileName) - String.length(Markdown.suffix);
       let name = String.sub(fileName, 0, length);
       let path = "posts/" ++ fileName;
       let (html, content) = Markdown.load(path);
       let metadata = BlogPost.parseMetadata(content, path);
       (name, html, metadata);
     })
  |> List.sort(((_, _, metadata1), (_, _, metadata2)) => {
       let date1 = Js.Date.fromString(metadata1.BlogPost.date);
       let date2 = Js.Date.fromString(metadata2.date);
       let diff = Js.Date.getTime(date2) -. Js.Date.getTime(date1);
       if (diff > 0.) {
         1;
       } else if (diff < 0.) {
         (-1);
       } else {
         0;
       };
     });

module MoreFs = {
  type stat;
  [@bs.val] [@bs.module "fs"] external lstatSync: string => stat = "lstatSync";
  [@bs.send] external isDirectory: stat => bool = "isDirectory";

  [@bs.val] [@bs.module "fs"]
  external copyFileSync: (string, string) => unit = "copyFileSync";

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
    "mkdirSync";

  [@bs.val] [@bs.module "fs"]
  external symlinkSync: (string, string) => unit = "symlinkSync";
};

module Router = {
  type t =
    | RawFile(string, React.element)
    | File(string, string => React.element)
    | Dir(string, array(t));

  let generateStatic = {
    let rec helper = path =>
      fun
      | RawFile(name, element) => {
          let path_ = path ++ "/" ++ name;
          writeStatic(path_, element);
        }
      | File(name, createElement) => {
          let path_ = path ++ "/" ++ name;
          MoreFs.mkdirSync(path_, {"recursive": true, "mode": 0o755});
          writeStatic(path_ ++ "/index", createElement("index"));
          /* TODO: remove when we do the redirect from the .html -> folder */
          writeStatic(path_, createElement(name));
        }
      | Dir(name, routes) => {
          let path_ = path ++ "/" ++ name;
          MoreFs.mkdirSync(path_, {"recursive": true, "mode": 0o755});
          routes |> Array.iter(helper(path_));
        };

    helper(".");
  };
};

let jobOpenings = [|
  (
    "protocol-reliability-engineer",
    "Protocol Reliability Engineer (San Francisco)",
  ),
  ("product-manager", "Product Manager (San Francisco)"),
  (
    "product-engineering-intern",
    "Product Engineering Intern (Frontend) (San Francisco)",
  ),
  ("visual-designer", "Visual Designer (San Francisco)"),
  ("protocol-engineer", "Senior Protocol Engineer (San Francisco)"),
  ("protocol-engineer-product", "Protocol Engineer (San Francisco)"),
|];

Rimraf.sync("site");
Rimraf.sync("docs-theme");

Router.(
  generateStatic(
    Dir(
      "site",
      [|
        RawFile(
          "index",
          <Page page=`Home name="index" footerColor=Style.Colors.navyBlue>
            <Home
              posts={List.map(
                ((name, html, metadata)) =>
                  (name, html, (metadata.BlogPost.title, "blog-" ++ name)),
                posts,
              )}
            />
          </Page>,
        ),
        Dir(
          "blog",
          posts
          |> Array.of_list
          |> Array.map(((name, html, metadata)) =>
               RawFile(
                 name,
                 <Page
                   page=`Blog
                   name
                   extraHeaders={Blog.extraHeaders()}
                   footerColor=Style.Colors.gandalf>
                   <Wrapped> <BlogPost name html metadata /> </Wrapped>
                 </Page>,
               )
             ),
        ),
        Dir(
          "jobs",
          jobOpenings
          |> Array.map(((name, _)) =>
               RawFile(
                 name,
                 <Page
                   page=`Jobs
                   name
                   footerColor=Style.Colors.gandalf
                   extraHeaders={CareerPost.extraHeaders()}>
                   <Wrapped>
                     <CareerPost path={"jobs/" ++ name ++ ".markdown"} />
                   </Wrapped>
                 </Page>,
               )
             ),
        ),
        File(
          "blog",
          name =>
            <Page page=`Blog name extraHeaders={Blog.extraHeaders()}>
              <Wrapped> <Blog posts /> </Wrapped>
            </Page>,
        ),
        File(
          "jobs",
          name =>
            <Page page=`Jobs name extraHeaders={Careers.extraHeaders()}>
              <Wrapped> <Careers jobOpenings /> </Wrapped>
            </Page>,
        ),
        File(
          "testnet",
          name =>
            <Page page=`Testnet name extraHeaders={Testnet.extraHeaders()}>
              <Wrapped> <Testnet /> </Wrapped>
            </Page>,
        ),
        File(
          "sfbw",
          name =>
            <Page page=`Sfbw name extraHeaders={Testnet.extraHeaders()}>
              <Wrapped> <Sfbw /> </Wrapped>
            </Page>,
        ),
        RawFile(
          "privacy",
          <Page page=`Privacy name="privacy">
            <RawHtml path="html/Privacy.html" />
          </Page>,
        ),
        RawFile(
          "tos",
          <Page page=`Tos name="tos"> <RawHtml path="html/TOS.html" /> </Page>,
        ),
      |],
    ),
  )
);

Router.(
  generateStatic(
    Dir(
      "docs-theme",
      [|
        RawFile(
          "main",
          <Page page=`Docs name="/docs/main">
            <Wrapped> <Docs /> </Wrapped>
          </Page>,
        ),
      |],
    ),
  )
);

let ignoreFiles = ["main.bc.js", "verifier_main.bc.js", ".DS_Store"];
let rec copyFolder = path => {
  MoreFs.mkdirSync("site/" ++ path, {"recursive": true, "mode": 0o755});
  Array.iter(
    s => {
      let path = Filename.concat(path, s);
      let isDir = MoreFs.lstatSync(path) |> MoreFs.isDirectory;
      if (isDir) {
        copyFolder(path);
      } else if (!List.mem(s, ignoreFiles)) {
        MoreFs.copyFileSync(
          path,
          "./site" ++ Links.Cdn.getHashedPath("/" ++ path),
        );
      };
    },
    Node.Fs.readdirSync(path),
  );
};

let moveToSite = path =>
  MoreFs.copyFileSync(path, Filename.concat("./site", path));

copyFolder("static");

// Special-case the jsoo-compiled files for now
// They can't be loaded from cdn so they get copied to the site separately
if (!Config.isProd) {
  moveToSite("static/main.bc.js");
  moveToSite("static/verifier_main.bc.js");
};

// Run mkdocs to generate static docs site
Markdown.Child_process.execSync(
  "mkdocs build -d site/docs",
  Markdown.Child_process.option(),
);

MoreFs.symlinkSync(
  Node.Process.cwd() ++ "/graphql-docs",
  "./site/docs/graphql",
);
