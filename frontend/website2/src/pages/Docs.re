module Style = {
  open Css;
  let sideNav =
    style([
      minWidth(rem(15.)),
      listStyleType(`none),
      firstChild([marginLeft(`zero)]),
      media(
        Theme.MediaQuery.somewhatLarge,
        [
          marginRight(rem(2.)),
          marginTop(rem(2.)),
          position(`sticky),
          top(rem(2.5)),
        ],
      ),
    ]);

  let navFolder =
    style([
      cursor(`pointer),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
      color(Theme.Colors.hyperlink),
      hover([color(Theme.Colors.hyperlinkHover)]),
    ]);
};

let (/+) = Filename.concat;

module NavPage = {
  [@react.component]
  let make = (~page: ContentType.DocsPage.t, ~currentPage) => {
    let isCurrentPage =
      currentPage
      |> Option.map(c => c.ContentType.DocsPage.slug == page.slug)
      |> Option.value(~default=false);
    // Hack for handling the root docs page
    let slug =
      Js.String.replaceByRe(Js.Re.fromString("index.html$"), "", page.slug);
    <li className={isCurrentPage ? Css.(style([fontWeight(`bold)])) : ""}>
      <Next.Link href="/docs/[slug]*" _as={"/docs/" ++ slug}>
        <a> {React.string(page.title)} </a>
      </Next.Link>
    </li>;
  };
};

module NavFolder = {
  [@react.component]
  let make = (~folder: ContentType.DocsFolder.t, ~inFolder, ~currentPage) => {
    let (expanded, setExpanded) = React.useState(() => inFolder);
    let toggleExpanded =
      React.useCallback(e => {
        ReactEvent.Mouse.preventDefault(e);
        setExpanded(expanded => !expanded);
      });

    <li key={folder.title}>
      <a
        href="#"
        className=Style.navFolder
        onClick=toggleExpanded
        ariaExpanded=expanded>
        {React.string(folder.title)}
      </a>
      {!expanded
         ? React.null
         : <ul>
             {folder.children
              |> Array.map(ContentType.Docs.fromDocsChild)
              |> Array.map((entry: ContentType.Docs.t) =>
                   switch (entry) {
                   | `Page(page) =>
                     <NavPage page currentPage key={page.slug} />
                   | `Folder(_) => React.null // Don't show nested folders
                   }
                 )
              |> React.array}
           </ul>}
    </li>;
  };
};

module SideNav = {
  [@react.component]
  let make =
      (
        ~docsRoot: ContentType.DocsFolder.t,
        ~currentFolder: option(ContentType.DocsFolder.t),
        ~currentPage: option(ContentType.DocsPage.t),
      ) => {
    <aside>
      <ul className=Style.sideNav>
        {docsRoot.children
         |> Array.map(ContentType.Docs.fromDocsChild)
         |> Array.map((entry: ContentType.Docs.t) =>
              switch (entry) {
              | `Page(page) => <NavPage page currentPage key={page.slug} />
              | `Folder(folder) =>
                let inFolder =
                  currentFolder
                  |> Option.map((curr: ContentType.DocsFolder.t) =>
                       folder.title == curr.title
                     )
                  |> Option.value(~default=false);
                <NavFolder folder inFolder currentPage key={folder.title} />;
              }
            )
         |> React.array}
      </ul>
    </aside>;
  };
};

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
       <div className=Css.(style([display(`flex)]))>
         <Next.Head> Markdown.katexStylesheet </Next.Head>
         <SideNav docsRoot currentFolder currentPage />
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
