let rec flattenPages = (currFolder, allPages) => {
  allPages
  |> Array.map(ContentType.Docs.fromDocsChild)
  |> Array.map(child =>
       switch ((child: ContentType.Docs.t)) {
       | `Page({slug} as page) => [|(slug, page, currFolder)|]
       | `Folder({children} as folder) =>
         flattenPages(Some(folder), children)
       }
     )
  |> Array.to_list
  |> Array.concat;
};

type pageContext = {
  before: option(ContentType.DocsPage.t),
  current: option(ContentType.DocsPage.t),
  after: option(ContentType.DocsPage.t),
  currentFolder: option(ContentType.DocsFolder.t),
};

let getCurrentAndSurroundingPage = (currentPath, flattenedPages) => {
  Array.fold_left(
    (acc, (pagePath, page: ContentType.DocsPage.t, folder)) =>
      switch (acc) {
      | {current: None} as ctx when currentPath == pagePath => {
          ...ctx,
          current: Some(page),
          currentFolder: folder,
        }
      | {current: None} as ctx => {...ctx, before: Some(page)}
      | {current: Some(_), after: None} as ctx => {
          ...ctx,
          after: Some(page),
        }
      | acc => acc
      },
    {before: None, current: None, after: None, currentFolder: None},
    flattenedPages,
  );
};

module Style = {
  open Css;
  let content =
    style([
      selector(
        "h1, h2, h3, h4",
        [
          display(`flex),
          marginTop(rem(2.)),
          marginBottom(`rem(0.5)),
          color(Theme.Colors.denimTwo),
          hover([selector(".headerlink", [display(`inlineBlock)])]),
        ],
      ),
      selector(
        "h1",
        Theme.H1.heroStyles @ [alignItems(`baseline), fontWeight(`normal)],
      ),
      selector("h2", Theme.H2.basicStyles @ [alignItems(`baseline)]),
      selector(
        "h3",
        Theme.H3.basicStyles
        @ [textAlign(`left), alignItems(`center), fontWeight(`medium)],
      ),
      selector(
        "p",
        [color(Theme.Colors.saville), ...Theme.Body.basicStyles],
      ),
      selector("a", Theme.Link.basicStylesHover),
      selector(
        "code",
        [Theme.Typeface.pragmataPro, color(Theme.Colors.midnight)],
      ),
      selector(
        "pre",
        [
          backgroundColor(Theme.Colors.slateAlpha(0.05)),
          borderRadius(`px(9)),
          padding2(~v=`rem(0.5), ~h=`rem(1.)),
          overflow(`scroll),
        ],
      ),
      selector(
        "ul, ol",
        [
          margin2(~v=`rem(1.), ~h=`zero),
          marginLeft(rem(1.5)),
          padding(`zero),
          ...Theme.Body.basicStyles,
        ],
      ),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Theme.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
      selector(
        "strong",
        [fontWeight(`num(600)), color(Theme.Colors.saville)],
      ),
    ]);
};

[@react.component]
let make =
    (~docsRoot: option(ContentType.DocsFolder.t), ~currentPath="index.html") => {
  <Page>
    {switch (docsRoot) {
     | Some(docsRoot) =>
       let flattenedPages = flattenPages(None, docsRoot.children);
       let {current: currentPage, currentFolder} =
         getCurrentAndSurroundingPage(currentPath, flattenedPages);
       <div
         className=Css.(
           style([
             display(`flex),
             justifyContent(`center),
             margin(`auto),
             paddingLeft(`rem(3.)),
             paddingRight(`rem(3.)),
           ])
         )>
         <Next.Head> Markdown.katexStylesheet </Next.Head>
         <DocsSideNav docsRoot currentFolder currentPage />
         {switch (currentPage) {
          | None => React.string("Couldn't find docs page: " ++ currentPath)
          | Some({content}) =>
            <div className=Style.content> <Markdown content /> </div>
          }}
       </div>;
     | None => React.string("Error: Couldn't retrieve docs")
     }}
  </Page>;
};

// TODO: Pull nav data separately, rather than all pages
Next.injectGetInitialProps(make, ({Next.query}) => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 10,
      "sys.id": "5ndZ0dMgzIIgVlKkueEQgD" // Entry ID of Root docs folder
    },
  )
  |> Js.Promise.then_((entries: ContentType.DocsFolder.entries) => {
       let root =
         switch (entries.items) {
         | [|item|] => Some(item.fields)
         | _ => None
         };
       Js.Promise.resolve({
         "docsRoot": root,
         "currentPath": Js.Dict.get(query, "slug"),
       });
     })
});
