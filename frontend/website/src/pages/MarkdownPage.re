// This is the layout for generic MDX pages

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
      selector(
        "table",
        [
          fontFamily("IBM Plex Sans, Sans-Serif"),
          color(Theme.Colors.saville),
          width(`percent(100.)),
        ],
      ),
      selector(
        "table, th, td",
        [
          border(`px(1), solid, Theme.Colors.saville),
          borderCollapse(`collapse),
          padding(`px(4)),
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
        <Next.MDXProvider components={DocsComponents.allComponents()}>
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
