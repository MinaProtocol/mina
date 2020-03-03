// This is the layout for the docs MDX pages
open Page.Footer;
module Style = {
  open! Css;

  let content =
    style([
      maxWidth(`rem(43.)),
      media(Theme.MediaQuery.notMobile, [marginLeft(`rem(1.))]),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Theme.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
    ]);

  let page =
    style([
      display(`block),
      justifyContent(`center),
      margin(`auto),
      marginTop(`rem(4.)),
      padding2(~v=`zero, ~h=`rem(2.)),
      media(Theme.MediaQuery.full, [display(`flex)]),
      media(Theme.MediaQuery.notMobile, [padding2(~v=`zero, ~h=`rem(3.))]),
    ]);

  let editLink =
    style([
      media(Theme.MediaQuery.tablet, [position(`relative), float(`right)]),
      display(`flex),
      alignItems(`center),
      marginTop(`rem(3.25)),
      marginBottom(`rem(0.5)),
      hover([color(Theme.Colors.hyperlinkHover)]),
      ...Theme.Link.basicStyles,
    ]);
  let footerStyle =
    Css.(
      style([
        Theme.Typeface.ibmplexsans,
        color(Theme.Colors.slate),
        textDecoration(`none),
        display(`inline),
        hover([color(Theme.Colors.hyperlink)]),
        fontSize(`rem(1.0)),
        fontWeight(`light),
        lineHeight(`rem(1.56)),
      ])
    );
};

module EditLink = {
  [@react.component]
  let make = (~route) => {
    <a
      name="Edit Link"
      target="_blank"
      href={
        "https://github.com/CodaProtocol/coda/edit/develop/frontend/website/pages"
        ++ route
        ++ ".mdx"
      }
      className=Style.editLink>
      <svg
        fill="currentColor"
        xmlns="http://www.w3.org/2000/svg"
        width="16"
        height="16"
        viewBox="0 0 24 24">
        <path
          d="M7.127 22.562l-7.127 1.438 1.438-7.128 5.689 5.69zm1.414-1.414l11.228-11.225-5.69-5.692-11.227 11.227 5.689 5.69zm9.768-21.148l-2.816 2.817 5.691 5.691 2.816-2.819-5.691-5.689z"
        />
      </svg>
      <span className=Css.(style([marginLeft(`rem(0.25))]))>
        {React.string("Edit")}
      </span>
    </a>;
  };
};

type metadata = {title: string};

[@react.component]
let make = (~metadata, ~children) => {
  let router = Next.Router.useRouter();
  let currentSlug =
    Js.String.replaceByRe(Js.Re.fromString("^/docs/?"), "", router.route);
  <Page title={metadata.title}>
    <div className=Style.page>
      <DocsSideNav currentSlug />
      <div className=Style.content>
        <EditLink route={router.route} />
        <Next.MDXProvider
          components={
            "Alert": Alert.make,
            "h1": DocsComponents.H1.make,
            "h2": DocsComponents.H2.make,
            "h3": DocsComponents.H3.make,
            "h4": DocsComponents.H4.make,
            "p": DocsComponents.P.make,
            "a": DocsComponents.A.make,
            "strong": DocsComponents.Strong.make,
            "pre": DocsComponents.Pre.make,
            "code": DocsComponents.Code.make,
            "ul": DocsComponents.Ul.make,
            "ol": DocsComponents.Ol.make,
          }>
          children
        </Next.MDXProvider>
      </div>
    </div>
    <footer>
      <section
        className=Css.(
          style([
            maxWidth(`rem(96.0)),
            marginLeft(`auto),
            marginRight(`auto),
            // Not using Theme.paddingY here because we need the background
            // color the same (so can't use margin), but we also need some
            // top spacing.
            paddingTop(`rem(4.75)),
          ])
        )>
        <div
          className=Css.(
            style([
              display(`flex),
              justifyContent(`center),
              textAlign(`center),
              marginBottom(`rem(2.0)),
            ])
          )>
          <ul
            className=Css.(
              style([listStyleType(`none), ...Theme.paddingX(`zero)])
            )>
            <Link link="/docs/en" name="English" notBlank=true>
              {React.string("English")}
            </Link>
            <Link link="/docs/de" name="German" notBlank=true last=true>
              {React.string("German")}
            </Link>
          </ul>
        </div>
      </section>
    </footer>
  </Page>;
};

let default =
  (. metadata) =>
    (. props: {. "children": React.element}) =>
      make({"metadata": metadata, "children": props##children});