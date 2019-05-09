module Styles = {
  open Css;

  let window =
    style([
      display(flexBox),
      flexDirection(column),
      alignItems(stretch),
      backgroundColor(white),
      width(pct(100.)),
      height(vh(100.)),
      overflow(`hidden),
    ]);
};

[@react.component]
let make = (~children) => <div className=Styles.window> children </div>;
