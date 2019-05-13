module Styles = {
  open Css;

  let window = 
    style([
      display(flexBox),
      flexDirection(column),
      alignItems(stretch),
      transition(~duration=200, "background"),
      background(`url("light-bg-texture.svg")),
      backgroundSize(`cover),
      width(pct(100.)),
      height(vh(100.)),
      overflow(`hidden),
    ]);
};

[@react.component]
let make = (~children) =>
  <div className={Styles.window}> children </div>;
