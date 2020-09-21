// This is the layout for the docs MDX pages

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
          backgroundColor(Theme.Colors.black),
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
      media(Theme.MediaQuery.desktop, [display(`flex)]),
      media(Theme.MediaQuery.notMobile, [padding2(~v=`zero, ~h=`rem(3.))]),
    ]);

  let editLink =
    style([
      media(Theme.MediaQuery.tablet, [position(`relative), float(`right)]),
      display(`flex),
      alignItems(`center),
      marginTop(`rem(3.25)),
      marginBottom(`rem(0.5)),
      hover([color(Theme.Colors.black)]),
    ]);
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
    <Next.Head>
      <link rel="stylesheet" href="/static/css/a11y-light.css" />
    </Next.Head>
    <div className=Style.page>
      <DocsSideNav currentSlug />
      <div className=Style.content>
        <EditLink route={router.route} />
        // <Next.MDXProvider components={DocsComponents.allComponents()}>
        <Next.MDXProvider> children </Next.MDXProvider>
      </div>
    </div>
  </Page>;
};

let default =
  (. metadata) =>
    (. props: {. "children": React.element}) =>
      make({"metadata": metadata, "children": props##children});
