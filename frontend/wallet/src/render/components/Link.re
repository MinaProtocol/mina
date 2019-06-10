type kind =
  | Blue
  | Grey
  | Red;

module Styles = {
  open Css;

  let link =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        cursor(`default),
        color(Theme.Colors.hyperlinkAlpha(0.7)),
        hover([color(Theme.Colors.hyperlink)]),
      ]),
    ]);

  let greyLink =
    merge([
      link,
      style([
        color(Theme.Colors.slateAlpha(0.5)),
        hover([color(Theme.Colors.hyperlinkAlpha(0.7))]),
      ]),
    ]);

  let redLink =
    merge([
      link,
      style([
        color(Theme.Colors.roseBudAlpha(0.7)),
        hover([color(Theme.Colors.roseBud)]),
      ]),
    ]);
};

[@react.component]
let make = (~children, ~onClick=?, ~kind=Blue) =>
  <a
    className={
      switch (kind) {
      | Blue => Styles.link
      | Red => Styles.redLink
      | Grey => Styles.greyLink
      }
    }
    ?onClick>
    children
  </a>;
