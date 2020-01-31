module Styles = {
  open Css;

  let ctaButton =
    style([
      background(`rgba((71, 137, 196, 0.1))),
      border(`px(1), `solid, Theme.Colors.hyperlink),
      borderRadius(`px(6)),
      textDecoration(`none),
      padding(`rem(1.0)),
      paddingTop(`rem(0.7)),
      minWidth(`rem(15.3)),
      hover([
        opacity(0.9),
        backgroundColor(Theme.Colors.azureAlpha(0.2)),
        border(`px(1), `solid, Theme.Colors.hyperlinkHover),
        cursor(`pointer),
      ]),
      media("(min-width: 70rem)", [height(`rem(6.875))]),
      media("(min-width: 82rem)", [height(`rem(6.0))]),
    ]);

  let ctaContent =
    style([display(`flex), selector("p", [fontSize(`px(36))])]);

  let ctaText = style([marginLeft(`px(13))]);

  let ctaHeading =
    style([
      Theme.Typeface.ibmplexsans,
      fontWeight(`num(600)),
      fontSize(`rem(1.875)),
      lineHeight(`rem(2.1875)),
      color(Theme.Colors.teal),
      textAlign(`left),
      paddingBottom(`rem(0.3)),
    ]);

  let ctaBody =
    style([
      Theme.Typeface.ibmplexsans,
      fontStyle(`normal),
      fontWeight(`normal),
      fontSize(`rem(0.8125)),
      color(Theme.Colors.teal),
      textAlign(`left),
      marginTop(`rem(0.0625)),
    ]);
  let ctaIcon =
    style([
      marginTop(`px(2)),
      minWidth(`px(36)),
      maxHeight(`px(48)),
      flexShrink(0.),
    ]);
};

[@react.component]
let make = (~icon, ~heading, ~text, ~href) => {
  <a href className=Styles.ctaButton>
    <div className=Styles.ctaContent>
      <p className=Styles.ctaIcon> icon </p>
      <div className=Styles.ctaText>
        <h2 className=Styles.ctaHeading> heading </h2>
        <h4 className=Styles.ctaBody> text </h4>
      </div>
    </div>
  </a>;
};
