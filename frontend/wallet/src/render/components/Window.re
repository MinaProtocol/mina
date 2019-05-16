module Styles = {
  open Css;

  let bg =
    style([
      transition(~duration=200, "background"),
      background(`url("light-bg-texture.svg")),
      backgroundSize(`cover),
    ]);

  let window =
    merge([
      style([
        display(flexBox),
        flexDirection(column),
        alignItems(stretch),
        width(pct(100.)),
        height(vh(100.)),
        overflow(`hidden),
      ]),
      bg,
    ]);
};

[@react.component]
let make = (~children) => <div className=Styles.window> children </div>;
