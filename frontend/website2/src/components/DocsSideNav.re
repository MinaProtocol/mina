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

  let page =
    merge([
      Theme.Link.basic,
      style([
        display(`inlineBlock),
        marginBottom(`rem(0.5)),
        height(`rem(1.5)),
      ]),
    ]);

  let currentPage =
    merge([
      page,
      style([
        fontWeight(`bolder),
        position(`relative),
        before([
          position(`absolute),
          left(rem(-0.75)),
          contentRule("\\2022 "),
        ]),
      ]),
    ]);

  let navFolder =
    style([
      display(`inlineBlock),
      marginBottom(`rem(0.5)),
      height(`rem(1.5)),
      cursor(`pointer),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
      color(Theme.Colors.marine),
      hover([color(Theme.Colors.hyperlinkHover)]),
    ]);

  let childPage = style([marginLeft(`rem(1.)), listStyleType(`none)]);
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
    <li>
      <Next.Link href="/docs/[slug]*" _as={"/docs/" ++ slug}>
        <a className={isCurrentPage ? Style.currentPage : Style.page}>
          {React.string(page.title)}
        </a>
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
         : <ul className=Style.childPage>
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
