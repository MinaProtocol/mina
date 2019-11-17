module Styles = {
  open Css;

  let container = style([marginLeft(`rem(3.0))]);

  let disabled = style([opacity(0.5), pointerEvents(`none)]);
};

[@react.component]
let make = (~children, ~disabled=false) =>
  <div
    className={Css.merge([Styles.container, disabled ? Styles.disabled : ""])}>
    children
  </div>;
