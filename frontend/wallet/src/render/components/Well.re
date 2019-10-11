module Styles = {
  open Css;

  let container =
    style([
      padding2(~v=`rem(0.75), ~h=`rem(1.)),
      border(`px(1), `solid, Theme.Colors.slateAlpha(0.4)),
      background(rgba(255, 255, 255, 0.8)),
      borderRadius(`px(6)),
      width(`rem(32.)),
    ]);

  let disabled = style([opacity(0.5), pointerEvents(`none)]);
};

[@react.component]
let make = (~children, ~disabled=false) =>
  <div
    className={Css.merge([Styles.container, disabled ? Styles.disabled : ""])}>
    children
  </div>;
