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
        background(Theme.Colors.amberAlpha(0.15)),
        selector("p", [color(Theme.Colors.clay)]),
      ]),
    ]);
  let green =
    merge([
      toast,
      style([
        background(Theme.Colors.mossAlpha(0.15)),
        selector("p", [color(Theme.Colors.clover)]),
      ]),
    ]);
  let red =
    merge([
      toast,
      style([
        background(Theme.Colors.yeezyAlpha(0.15)),
        selector("p", [color(Theme.Colors.yeezy)]),
      ]),
    ]);
};

[@react.component]
let make = () => {
  let (value, _) = React.useContext(ToastProvider.context);

  switch (value) {
  | Some({text, style}) =>
    <div
      className={
        switch (style) {
        | ToastProvider.Error => Styles.red
        | Success => Styles.green
        | Warning => Styles.yellow
        | Default => Styles.blue
        }
      }>
      <p className=Theme.Text.Body.regular> {React.string(text)} </p>
    </div>
  | None => React.null
  };
};
