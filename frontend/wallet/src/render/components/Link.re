module Styles = {
  open Css;

  let link =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        color(Theme.Colors.slateAlpha(0.5)),
        cursor(`pointer),
        hover([color(Theme.Colors.hyperlinkAlpha(0.7))]),
      ]),
    ]);
};

[@react.component]
let make = (~children, ~onClick=?) =>
  <a className=Styles.link ?onClick> children </a>;
