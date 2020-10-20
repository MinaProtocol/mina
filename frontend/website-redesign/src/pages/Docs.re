// This is the layout for the docs MDX pages

module Style = {
  open! Css;

  let content =
    style([
      maxWidth(`rem(53.)),
      marginBottom(`rem(2.875)),
      media(Theme.MediaQuery.notMobile, [marginLeft(`rem(1.))]),
      selector("p > code, li > code", Theme.Type.inlineCode_),
      selector("h1 + p", Theme.Type.sectionSubhead_),
    ]);

  let page =
    style([
      display(`flex),
      justifyContent(`center),
      margin(`auto),
      marginTop(`rem(2.)),
      paddingBottom(`rem(6.)),
      media(Theme.MediaQuery.desktop, [justifyContent(`spaceBetween)]),
    ]);

  let blogBackground =
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/backgrounds/BlogBackground.jpg")),
    ]);

  let eyebrow = style([marginBottom(`rem(1.))]);

  let editLink =
    style([
      media(Theme.MediaQuery.tablet, [position(`relative), float(`right)]),
      display(`flex),
      alignItems(`center),
      marginTop(`rem(1.5)),
      marginBottom(`rem(0.5)),
      textDecoration(`none),
      color(Theme.Colors.orange),
    ]);

  let link = merge([Theme.Type.link, style([])]);
};

module EditLink = {
  [@react.component]
  let make = (~route) => {
    <a
      name="Edit Link"
      target="_blank"
      href={
        "https://github.com/MinaProtocol/mina/edit/develop/frontend/website/pages"
        ++ route
        ++ ".mdx"
      }
      className=Style.editLink>
      <span className=Style.link> {React.string("Edit")} </span>
      <Icon kind=Icon.ArrowRightMedium />
    </a>;
  };
};

type metadata = {title: string};

[@react.component]
let make = (~metadata, ~children) => {
  let router = Next.Router.useRouter();
  let currentSlug =
    if (router.route == "/docs") {
      "/docs";
    } else {
      Js.String.replaceByRe(
        Js.Re.fromString("^/docs/?"),
        "/docs/",
        router.route,
      );
    };
  <Page title={metadata.title}>
    <Next.Head>
      <link rel="stylesheet" href="/static/css/a11y-light.css" />
    </Next.Head>
    <div className=Style.blogBackground>
      <Wrapped>
        <div className=Nav.Styles.spacer />
        <div className=Style.page>
          <DocsSideNav currentSlug />
          <div className=Style.content>
            <div className=Style.eyebrow>
              <LabelEyebrow copy="Documentation" />
            </div>
            <EditLink route={router.route} />
            <Next.MDXProvider components={DocsComponents.allComponents()}>
              children
            </Next.MDXProvider>
          </div>
        </div>
      </Wrapped>
    </div>
  </Page>;
};

let default =
  (. metadata) =>
    (. props: {. "children": React.element}) =>
      make({"metadata": metadata, "children": props##children});
