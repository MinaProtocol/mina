open Css;

module Style = {
  let container =
    style([
      position(`relative),
      height(`rem(19.68)),
      borderRadius(`px(6)),
      boxSizing(`borderBox),
      backgroundColor(Theme.Colors.babyBlue),
      backgroundImage(`url("/static/img/Bg.SecurityWave.png")),
      padding2(~v=`rem(2.5), ~h=`rem(3.12)),
      border(`px(1), `solid, Theme.Colors.marine),
      width(`rem(20.)),
      media(
        Theme.MediaQuery.tablet,
        [width(`rem(17.5)), padding2(~v=`rem(2.5), ~h=`rem(2.5))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [width(`rem(21.25)), padding2(~v=`rem(2.5), ~h=`rem(3.12))],
      ),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
    ]);

  let image = style([alignSelf(`center)]);
  let background =
    style([
      position(`absolute),
      top(`zero),
      right(`zero),
      display(`inlineBlock),
    ]);

  let label =
    merge([
      Theme.H3.basic,
      style([alignSelf(`center), color(Theme.Colors.marine)]),
    ]);
  let labelSemiBold = merge([label, style([fontWeight(`semiBold)])]);
  let ctaButton =
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Theme.Colors.hyperlink),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(Theme.Colors.hyperlinkHover)]),
      ]),
    ]);
};

[@react.component]
let make = (~target=?, ~labelStep, ~label, ~image, ~buttonLabel, ~buttonLink) => {
  <div className=Style.container ariaLabel=label>
    <label className=Style.label>
      <span className=Style.labelSemiBold> {React.string(labelStep)} </span>
      {React.string(label)}
    </label>
    <img src=image className=Style.image />
    <a ?target className=Style.ctaButton href=buttonLink>
      {React.string(buttonLabel)}
    </a>
  </div>;
};
