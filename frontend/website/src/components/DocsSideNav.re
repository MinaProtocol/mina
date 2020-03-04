open Locales;

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
//method to get the key of location e.g "en"
let getLocaleKey = () => {
    let localeOpt = if([%bs.raw {| process.browser |}]){
      let pathName = [%bs.raw {| window.location.pathname |}];
      let regex = [%re "/\//"];
        let results = Js.String.splitByRe(regex, pathName);
        Option.value(~default="en",results[2]);
    }
    //if no browser process is found, just return english
    else {
        "en"
    }
    localeOpt;
}
module CurrentSlugProvider = {
  let (context, make, makeProps) = ReactExt.createContext("");
};

module FolderSlugProvider = {
  let (context, make, makeProps) = ReactExt.createContext(None);
};

let slugConcat = (n1, n2) => {
  String.length(n2) > 0 ? n1 ++ "/" ++ n2 : n1;
};

module Page = {
  [@react.component]
  let make = (~title, ~slug) => {
    let currentSlug = React.useContext(CurrentSlugProvider.context);
    let folderSlug = React.useContext(FolderSlugProvider.context);
    let fullSlug =
      switch (folderSlug) {
      | Some(fs) => slugConcat(fs, slug)
      | None => slug
      };
    let isCurrentPage = currentSlug == fullSlug;
    let href = slugConcat("/docs/"++getLocaleKey(), fullSlug);
    <li>
      <Next.Link href>
        <a className={isCurrentPage ? Style.currentPage : Style.page}>
          {React.string(title)}
        </a>
      </Next.Link>
    </li>;
  };
};

module Folder = {
  [@react.component]
  let make = (~title, ~slug, ~children) => {
    let currentSlug = React.useContext(CurrentSlugProvider.context);
    let hasCurrentSlug = ref(false);

    // Check if the children's props contain the current slug
    ReactExt.Children.forEach(children, (. child) => {
      switch (ReactExt.props(child)##slug) {
      | Some(childSlug) when slugConcat(slug, childSlug) == currentSlug =>
        hasCurrentSlug := true
      | _ => ()
      }
    });

    let (expanded, setExpanded) = React.useState(() => hasCurrentSlug^);

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
            className={expanded ? Style.flip : ""}
          />
        </a>
      </div>
      {!expanded
         ? React.null
         : <FolderSlugProvider value={Some(slug)}>
             <ul className=Style.childPage> children </ul>
           </FolderSlugProvider>}
    </li>;
  };
};

let getLocales = () => {
    let localeOpt = getLocaleKey();

    switch(localeOpt){
    | "de" => DocsLocales.gerTitles;
    | "en" => DocsLocales.engTitles;
    | _ => DocsLocales.engTitles
    }

};

[@react.component]
let make = (~currentSlug) => {
  <aside>
    <CurrentSlugProvider value=currentSlug>
      <ul className=Style.sideNav>
        <Page title=getLocales().overview slug="" />
        <Page
          title=getLocales().gettingStarted
          slug="getting-started"
        />
        <Page title=getLocales().firstTransaction slug="my-first-transaction" />
        <Page title=getLocales().becomeANodeOperator slug="node-operator" />
        <Page title=getLocales().contributing slug="contributing" />
        <Folder title=getLocales().developersFolder slug="developers">
          <Page title=getLocales().developersOverview slug="" />
          <Page title=getLocales().codebaseOverview slug="codebase-overview" />
          <Page title=getLocales().repositoryStructure slug="directory-structure" />
          <Page title=getLocales().codeReviews slug="code-reviews" />
          <Page title=getLocales().styleGuide slug="style-guide" />
          <Page title=getLocales().graphqlApi slug="graphql-api" />
        </Folder>
        <Folder title=getLocales().codaProtocolArchitectureFolder slug="architecture">
          <Page title=getLocales().codaOverview slug="" />
          <Page title=getLocales().lifecycleOfPayment slug="lifecycle-payment" />
          <Page title=getLocales().consensus slug="consensus" />
          <Page title=getLocales().proofOfStake slug="proof-of-stake" />
        </Folder>
        <Folder title=getLocales().snarksFolder slug="snarks">
          <Page title=getLocales().snarksOverview slug="" />
          <Page title=getLocales().snarksGettingStarted slug="snarky" />
          <Page title=getLocales().whichSnark slug="constructions" />
          <Page title=getLocales().snarkyCryptoLib slug="snarkyjs-crypto" />
          <Page title=getLocales().snarkyUniverseLib slug="snarky-universe" />
        </Folder>
        <Page title=getLocales().guiWallet slug="gui-wallet" />
        <Page title=getLocales().cliReference slug="cli-reference" />
        <Page title=getLocales().troubleshooting slug="troubleshooting" />
        <Page title=getLocales().faq slug="faq" />
        <Page title=getLocales().glossary slug="glossary" />
      </ul>
    </CurrentSlugProvider>
  </aside>;
};