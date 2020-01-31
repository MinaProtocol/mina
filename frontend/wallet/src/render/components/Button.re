open ReactIntl;

type mode =
  | Blue
  | HyperlinkBlue
  | Gray
  | Green
  | Red;

module Styles = {
  open Css;

  let base =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        justifyContent(`center),
        padding2(~v=`zero, ~h=`rem(1.)),
        background(white),
        border(`px(0), `solid, white),
        borderRadius(`rem(0.25)),
        active([outlineStyle(`none)]),
        focus([outlineStyle(`none)]),
        disabled([pointerEvents(`none)]),
      ]),
    ]);

  let blue =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.marineAlpha(0.1)),
        color(Theme.Colors.marineAlpha(1.)),
        hover([backgroundColor(Theme.Colors.marine), color(white)]),
        focus([backgroundColor(Theme.Colors.marine), color(white)]),
        active([backgroundColor(Theme.Colors.marine), color(white)]),
      ]),
    ]);

  let hyperlinkBlue =
    merge([
      base,
      style([
        color(Theme.Colors.hyperlink),
        backgroundColor(Theme.Colors.hyperlinkAlpha(0.15)),
        hover([backgroundColor(Theme.Colors.hyperlink), color(white)]),
        focus([backgroundColor(Theme.Colors.hyperlink), color(white)]),
        active([backgroundColor(Theme.Colors.hyperlink), color(white)]),
      ]),
    ]);

  let green =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.serpentine),
        color(white),
        hover([backgroundColor(Theme.Colors.jungle)]),
        focus([backgroundColor(Theme.Colors.jungle)]),
        active([backgroundColor(Theme.Colors.jungle)]),
      ]),
    ]);

  let red =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.roseBud),
        color(white),
        hover([backgroundColor(Theme.Colors.yeezy)]),
        focus([backgroundColor(Theme.Colors.yeezy)]),
        active([backgroundColor(Theme.Colors.yeezy)]),
      ]),
    ]);

  let gray =
    merge([
      base,
      style([
        backgroundColor(Theme.Colors.slateAlpha(0.05)),
        color(Theme.Colors.midnight),
        hover([backgroundColor(Theme.Colors.slateAlpha(0.2))]),
        focus([backgroundColor(Theme.Colors.slateAlpha(0.2))]),
        active([backgroundColor(Theme.Colors.slateAlpha(0.2))]),
      ]),
    ]);

  let disabled = style([opacity(0.5)]);
};

[@react.component]
let make =
    (
      ~label,
      ~onClick=?,
      ~style=Blue,
      ~disabled=false,
      ~width=10.5,
      ~height=3.,
      ~icon=?,
      ~type_="button",
      ~onMouseEnter=?,
      ~onMouseLeave=?,
    ) =>
  <button
    disabled
    ?onClick
    ?onMouseEnter
    ?onMouseLeave
    className={Css.merge([
      disabled ? Styles.disabled : "",
      Css.style([
        Css.minWidth(`rem(width)),
        Css.height(`rem(height)),
        Css.textTransform(`capitalize),
      ]),
      switch (style) {
      | Blue => Styles.blue
      | Green => Styles.green
      | Red => Styles.red
      | Gray => Styles.gray
      | HyperlinkBlue => Styles.hyperlinkBlue
      },
    ])}
    type_>
    {switch (icon) {
     | Some(kind) => <Icon kind />
     | None => React.null
     }}
    <FormattedMessage id=label defaultMessage=label />
  </button>;