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
          | Some({content}) => <Markdown content />
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
