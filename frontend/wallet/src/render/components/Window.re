module Styles = {
  open Css;

  let fadeIn =
    keyframes([
      (0, [opacity(0.)]),
      (50, [opacity(0.)]),
      (100, [opacity(1.)]),
    ]);

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
        animation(fadeIn, ~duration=750, ~iterationCount=`count(1)),
      ]),
      bg,
    ]);
};

[@react.component]
let make = (~children) => <div className=Styles.window> children </div>;
