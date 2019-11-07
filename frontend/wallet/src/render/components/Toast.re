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
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> add onClick to toast
let make =
    (
      ~defaultText=?,
      ~style as styleOverride=ToastProvider.Default,
      ~onClick: unit => unit=() => (),
    ) => {
<<<<<<< HEAD
  let (value, _) = React.useContext(ToastProvider.context);
  let value =
    Option.map(value, ~f=({ToastProvider.text, style}) => (text, style));
  let default = Option.map(defaultText, ~f=text => (text, styleOverride));
=======
let make = (~defaultText=?) => {
  let (value, _) = React.useContext(ToastProvider.context);
  let value =
    Option.map(value, ~f=({ToastProvider.text, style}) => (text, style));
  let default =
    Option.map(defaultText, ~f=text => (text, ToastProvider.Default));
>>>>>>> Wallet: add default toast
=======
  let (value, _) = React.useContext(ToastProvider.context);
  let value =
    Option.map(value, ~f=({ToastProvider.text, style}) => (text, style));
  let default = Option.map(defaultText, ~f=text => (text, styleOverride));
>>>>>>> add onClick to toast

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
