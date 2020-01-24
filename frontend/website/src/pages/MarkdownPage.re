// This is the layout for the docs MDX pages

module Style = {
  open Css;

  let content =
    style([
      maxWidth(`rem(43.)),
      marginLeft(`rem(1.)),
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
      paddingLeft(`rem(1.)),
      paddingRight(`rem(1.)),
      marginTop(`rem(4.)),
      media(Theme.MediaQuery.full, [display(`flex)]),
    ]);
};

type metadata = {title: string};

[@react.component]
let make = (~metadata, ~children) => {
  <Page title={metadata.title}>
    <div className=Style.page>
      <div className=Style.content>
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
  </Page>;
};

let default =
  (. metadata) =>
    (. props: {. "children": React.element}) =>
      make({"metadata": metadata, "children": props##children});
