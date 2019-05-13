type mode =
  | Blue
  | Gray
  | Green
  | Red;

module Styles = {
  open Css;

  let base =
    merge([
      Theme.Text.body,
      style([
        display(`inlineFlex),
        alignItems(`center),
        justifyContent(`center),
        height(`rem(2.5)),
        minWidth(`rem(12.5)),
        padding2(~v=`zero,~h=`rem(1.)),
        background(white),
        border(`px(0), `solid, white),
        borderRadius(`rem(0.25)),
        cursor(`pointer),
        active([outlineStyle(`none)]),
        focus([outlineStyle(`none)]),
      ]),
    ]);
  
  let blue =
    merge([
      base,
      style([
        backgroundColor(lightblue),
        color(white),
        hover([backgroundColor(Theme.Colors.jungle)]),
      ]),
    ]);

  let green =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.serpentine),
        color(white),
        hover([backgroundColor(Theme.Colors.jungle)]),
      ]),
    ]);
  
  let red =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.roseBud),
        color(white),
        hover([backgroundColor(Theme.Colors.yeezy)]),
      ]),
    ]);

  let gray =
    merge([
      base,
      style([
        backgroundColor(grey),
        color(white),
        hover([backgroundColor(darkgrey)])
      ]),
    ]);
};

[@react.component]
let make = (~label, ~style=Blue) =>
  <button
    className={
      switch (style) {
      | Blue => Styles.blue
      | Green => Styles.green
      | Red => Styles.red
      | Gray => Styles.gray
      }
    }>
    {React.string(label)}
  </button>;
