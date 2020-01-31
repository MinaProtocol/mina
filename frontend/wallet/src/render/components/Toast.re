open Tc;

module Styles = {
  open Css;
  let toast = (bgColor, textColor) =>
    style([
      borderRadius(`px(4)),
      selector("p", [color(textColor), margin2(~v=`px(2), ~h=`px(10))]),
      background(bgColor),
    ]);
};

[@react.component]
let make =
    (
      ~defaultText=?,
      ~defaultStyle=ToastProvider.Default,
      ~onClick: unit => unit=() => (),
    ) => {
  let (value, _) = React.useContext(ToastProvider.context);
  let value =
    Option.map(value, ~f=({ToastProvider.text, style}) => (text, style));
  let default = Option.map(defaultText, ~f=text => (text, defaultStyle));

  // The second arg to orElse has precedence
  switch (Option.orElse(default, value)) {
  | Some((text, style)) =>
    let (bgColor, textColor) =
      Theme.Colors.(
        switch (style) {
        | ToastProvider.Success => (mossAlpha(0.15), clover)
        | Error => (amberAlpha(0.15), clay)
        | Default => (hyperlinkAlpha(0.15), marine)
        | Warning => (yeezyAlpha(0.15), yeezy)
        }
      );
    <div
      className={Styles.toast(bgColor, textColor)} onClick={_ => onClick()}>
      <p className=Theme.Text.Body.regular> {React.string(text)} </p>
    </div>;
  | None => React.null
  };
};
