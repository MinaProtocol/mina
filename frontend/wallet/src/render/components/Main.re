module Styles = {
  open Css;

  let main =
    style([
      display(`flex),
      flexDirection(`row),
      position(`relative),
      paddingTop(Theme.Spacing.headerHeight),
      paddingBottom(Theme.Spacing.footerHeight),
      height(`vh(100.)),
      width(`vw(100.)),
    ]);
};

[@react.component]
let make = (~children) => {
  <main className=Styles.main> children </main>;
};
