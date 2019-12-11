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
      display(`block),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      selector(
        "a",
        [
          marginBottom(`rem(0.5)),
          height(`rem(1.5)),
          cursor(`pointer),
          textDecoration(`none),
          Theme.Typeface.ibmplexsans,
          hover([color(Theme.Colors.hyperlinkHover)]),
        ],
      ),
    ]);
  let folderLabel =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      color(Theme.Colors.marine),
    ]);
  let childPage = style([marginLeft(`rem(1.)), listStyleType(`none)]);
  let flip = style([transform(rotate(`deg(180.)))]);
};

module NavPage = {
  [@react.component]
  let make = (~title, ~slug, ~currentSlug) => {
    let isCurrentPage =
      currentSlug
      |> Option.map(s => s == slug)
      |> Option.value(~default=false);
    // Special case for the docs index page
    let href = String.length(slug) > 0 ? "/docs/" ++ slug : "/docs";
    <li>
      <Next.Link href>
        <a className={isCurrentPage ? Style.currentPage : Style.page}>
          {React.string(title)}
        </a>
      </Next.Link>
    </li>;
  };
};

module NavFolder = {
  [@react.component]
  let make = (~title, ~pages, ~inFolder, ~currentSlug) => {
    let (expanded, setExpanded) = React.useState(() => inFolder);
    let toggleExpanded =
      React.useCallback(e => {
        ReactEvent.Mouse.preventDefault(e);
        setExpanded(expanded => !expanded);
      });

    <li key=title className=Style.navFolder>
      <div>
        <a
          href="#"
          onClick=toggleExpanded
          ariaExpanded=expanded
          className=Style.folderLabel>
          {React.string(title)}
          <Spacer width=1.0 />
          <img
            src="/static/img/chevron-down.svg"
            width="16"
            height="16"
            className={expanded ? "" : Style.flip}
          />
        </a>
      </div>
      {!expanded
         ? React.null
         : <ul className=Style.childPage>
             {pages
              |> Array.map(entry =>
                   switch ((entry: DocsStructure.t)) {
                   | Page(title, slug) =>
                     <NavPage title slug currentSlug key=slug />
                   | Folder(_, _) => React.null // Don't show nested folders
                   }
                 )
              |> React.array}
           </ul>}
    </li>;
  };
};

[@react.component]
let make = (~currentSlug=?) => {
  <aside>
    <ul className=Style.sideNav>
      {DocsStructure.structure
       |> Array.map(entry =>
            switch ((entry: DocsStructure.t)) {
            | Page(title, slug) => <NavPage title slug currentSlug key=slug />
            | Folder(title, children) =>
              let inFolder =
                children
                |> Array.exists(page =>
                     switch (page: DocsStructure.t, currentSlug) {
                     | (Page(_title, slug), Some(current)) =>
                       slug == current
                     | _ => false // nest folders only 1 deep
                     }
                   );
              <NavFolder
                title
                pages=children
                inFolder
                currentSlug
                key=title
              />;
            }
          )
       |> React.array}
    </ul>
  </aside>;
};
