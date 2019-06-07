type color =
  | Slate
  | Red
  | Teal;

module Styles = {
  open Css;

  let link =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        cursor(`default),
      ]),
    ]);

  let slate =
    style([
      color(Theme.Colors.slateAlpha(0.5)),
      hover([color(Theme.Colors.hyperlinkAlpha(0.7))]),
    ]);

  let red =
    style([
      color(Theme.Colors.roseBudAlpha(0.5)),
      hover([color(Theme.Colors.roseBud)]),
    ]);
  
  let teal =
    style([
      color(Theme.Colors.teal),
      hover([color(Theme.Colors.hyperlinkAlpha(1.))]),
    ]);
};

[@react.component]
let make = (
    ~children,
    ~onClick=?,
    ~color=Slate,
  ) =>
  <a
    className={Css.merge([
      Styles.link,
      switch (color) {
      | Slate => Styles.slate
      | Red => Styles.red
      | Teal => Styles.teal
      },
    ])}
    ?onClick
  >
    children
  </a>;
