open ReactIntl;

type mode =
  | HyperlinkBlue
  | Gray
  | Green
  | Red
  | OffWhite
  | MidnightBlue
  | HyperlinkBlue2
  | HyperlinkBlue3
  | LightBlue;

module Styles = {
  open Css;

  let base =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        justifyContent(`center),
        background(white),
        border(`px(0), `solid, white),
        borderRadius(`rem(0.25)),
        active([outlineStyle(`none)]),
        focus([outlineStyle(`none)]),
        disabled([pointerEvents(`none)]),
      ]),
    ]);

  let buttonLink = style([textDecoration(`none), color(white)]);
  let buttonColor = mode =>
    switch (mode) {
    | HyperlinkBlue => white
    | Gray => Theme.Colors.midnight
    | Green => white
    | Red => white
    | OffWhite => white
    | MidnightBlue => white
    | HyperlinkBlue2 => white
    | HyperlinkBlue3 => white
    | LightBlue => Theme.Colors.hyperlink
    };

  let buttonBgColor = mode =>
    switch (mode) {
    | HyperlinkBlue => Theme.Colors.hyperlink
    | Gray => Theme.Colors.slateAlpha(0.05)
    | Green => Theme.Colors.serpentine
    | Red => Theme.Colors.roseBud
    | OffWhite => Theme.Colors.offWhite(0.2)
    | MidnightBlue => Theme.Colors.hyperlinkAlpha(0.3)
    | HyperlinkBlue2 => Theme.Colors.hyperlinkAlpha(0.3)
    | HyperlinkBlue3 => Theme.Colors.hyperlink
    | LightBlue => Theme.Colors.marineAlpha(0.1)
    };

  let buttonHoverBgColor = mode =>
    switch (mode) {
    | HyperlinkBlue => Theme.Colors.hyperlinkAlpha(0.3)
    | Gray => Theme.Colors.slateAlpha(0.2)
    | Green => Theme.Colors.jungle
    | Red => Theme.Colors.yeezy
    | OffWhite => Theme.Colors.offWhite(0.5)
    | MidnightBlue => Theme.Colors.hyperlink
    | HyperlinkBlue2 => Theme.Colors.hyperlinkAlpha(0.7)
    | HyperlinkBlue3 => Theme.Colors.blue3
    | LightBlue => Theme.Colors.hyperlink
    };

  let buttonHoverColor = mode =>
    switch (mode) {
    | HyperlinkBlue => white
    | Gray => Theme.Colors.midnight
    | Green => white
    | Red => white
    | OffWhite => white
    | MidnightBlue => white
    | HyperlinkBlue2 => white
    | HyperlinkBlue3 => white
    | LightBlue => white
    };

  let buttonStyles = mode =>
    merge([
      base,
      style([
        backgroundColor(buttonBgColor(mode)),
        color(buttonColor(mode)),
        hover([
          backgroundColor(buttonHoverBgColor(mode)),
          color(buttonHoverColor(mode)),
          cursor(`pointer),
        ]),
        focus([backgroundColor(buttonHoverBgColor(mode))]),
        active([backgroundColor(buttonHoverBgColor(mode))]),
      ]),
    ]);

  let disabled = style([opacity(0.5)]);
};

[@react.component]
let make =
    (
      ~label,
      ~onClick=?,
      ~style=HyperlinkBlue,
      ~disabled=false,
      ~width=10.5,
      ~height=3.,
      ~padding=1.,
      ~icon=?,
      ~type_="button",
      ~onMouseEnter=?,
      ~onMouseLeave=?,
      ~link=?,
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
        Css.padding2(~v=`zero, ~h=`rem(padding)),
      ]),
      Styles.buttonStyles(style),
    ])}
    type_>
    {switch (link, icon) {
     | (Some(link), Some(icon)) =>
       <>
         <Icon kind=icon />
         <a href=link className=Styles.buttonLink target="_blank">
           {React.string(label)}
         </a>
       </>
     | (None, None) => React.string(label)
     | (None, Some(icon)) => <> <Icon kind=icon /> {React.string(label)} </>
     | (Some(link), None) =>
       <a href=link target="_blank"> {React.string(label)} </a>
     }}
  </button>;

