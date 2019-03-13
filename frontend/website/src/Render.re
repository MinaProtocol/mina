[@bs.module "emotion-server"]
external renderStylesToString: string => string = "";

type critical = {
  .
  "html": string,
  "css": string,
};

[@bs.module "emotion-server"]
external extractCritical: string => critical = "";

let writeStatic = (path, rootComponent) => {
  let rendered =
    extractCritical(ReactDOMServerRe.renderToStaticMarkup(rootComponent));
  Node.Fs.writeFileAsUtf8Sync(
    "site/" ++ path ++ ".html",
    "<!doctype html><meta charset=\"utf-8\" />\n" ++ rendered##html,
  );
  Node.Fs.writeFileAsUtf8Sync("site/" ++ path ++ ".css", rendered##css);
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
       print_endline("success " ++ name);
       (name, content, html);
     });

// TODO: Parse metadata from markdown
Array.iter(
  ((name, content, html)) =>
    writeStatic(
      "blog/" ++ name,
      <Page extraHeaders=BlogPost.extraHeaders>
        <BlogPost
          name
          title="A SNARKy Exponential Function"
          subtitle="Simulating real numbers using finite field arithmetic"
          author="Izaak Meckler"
          authorWebsite="www.twitter.com/imeckler"
          date="March 09 2019"
          html
        />
      </Page>,
    ),
  posts,
);

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

writeStatic(
  "jobs",
  <Page extraHeaders=Careers.extraHeaders> <Careers jobOpenings /> </Page>,
);
