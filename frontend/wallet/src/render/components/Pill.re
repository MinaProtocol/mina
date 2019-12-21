type mode =
  | Grey
  | Blue
  | DarkBlue
  | Green;

module Styles = {
  open Css;

  let base =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`center),
      height(`rem(1.5)),
      padding2(~v=`zero, ~h=`rem(0.5)),
      borderRadius(`rem(0.25)),
      overflow(`hidden),
    ]);

  let grey =
    merge([
      base,
      style([backgroundColor(Theme.Colors.midnightAlpha(0.06))]),
    ]);

  let green =
    merge([base, style([backgroundColor(Theme.Colors.serpentineLight)])]);

  let blue =
    merge([base, style([backgroundColor(Theme.Colors.marineAlpha(0.1))])]);

  let darkBlue =
    merge([base, style([backgroundColor(Theme.Colors.marine)])]);
};

[@react.component]
let make = (~mode=Grey, ~children) => {
  <span
    className={
      switch (mode) {
      | Grey => Styles.grey
      | Green => Styles.green
      | Blue => Styles.blue
      | DarkBlue => Styles.darkBlue
      }
    }>
    children
  </span>;
};
