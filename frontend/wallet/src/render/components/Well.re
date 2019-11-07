module Styles = {
  open Css;

  let container =
    style([
      padding2(~v=`rem(0.75), ~h=`rem(1.)),
      border(`px(1), `solid, Theme.Colors.slateAlpha(0.4)),
      borderRadius(`px(6)),
      minWidth(`rem(32.)),
    ]);

  let disabled = style([opacity(0.5), pointerEvents(`none)]);
};

[@react.component]
let make = (~children, ~disabled=false) =>
  <div
    className={Css.merge([Styles.container, disabled ? Styles.disabled : ""])}>
    children
  </div>;
