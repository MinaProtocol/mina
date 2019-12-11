// This is the layout for the docs MDX pages

module Style = {
  open Css;

  let content =
    style([
      maxWidth(`rem(43.)),
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
      display(`flex),
      justifyContent(`center),
      margin(`auto),
      paddingLeft(`rem(3.)),
      paddingRight(`rem(3.)),
    ]);
};

[@react.component]
let make = (~children) => {
  let router = Next.Router.useRouter();
  let currentSlug =
    Js.String.replaceByRe(Js.Re.fromString("^/docs/?"), "", router.route);
  <Page>
    <div className=Style.page>
      <DocsSideNav currentSlug />
      <div className=Style.content>
        <Next.MDXProvider
          components={
            "Alert": Alert.make,
            "Metadata": DocsComponents.Metadata.make,
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
  </Page>;
};

let default = make;
