type mode =
  | Blue
  | Yellow
  | Green
  | Red;

module Styles = {
  open Css;
  let toast =
    style([
      borderRadius(`px(4)),
      selector("p", [margin2(~v=`px(2), ~h=`px(10))]),
    ]);
  let blue =
    merge([
      toast,
      style([
        background(Theme.Colors.marine),
        selector("p", [color(white)]),
      ]),
    ]);
  let yellow =
    merge([
      toast,
      style([
        background(Theme.Colors.amberAlpha(1.)),
        selector("p", [color(Theme.Colors.clay)]),
      ]),
    ]);
  let green =
    merge([
      toast,
      style([
        background(Theme.Colors.clover),
        selector("p", [color(white)]),
      ]),
    ]);
  let red =
    merge([
      toast,
      style([
        background(Theme.Colors.yeezy),
        selector("p", [color(white)]),
      ]),
    ]);
};

[@react.component]
let make = (~style=Blue) => {
  <div
    className={
      switch (style) {
      | Blue => Styles.blue
      | Yellow => Styles.yellow
      | Green => Styles.green
      | Red => Styles.red
      }
    }>
    <p className=Theme.Text.Body.regular>
      {React.string("Public key copied to clipboard")}
    </p>
  </div>;
};
