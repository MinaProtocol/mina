module Styles = {
  open Css;

  let ctaButton =
    style([
      padding(`rem(1.125)),
      background(`rgba((71, 137, 196, 0.1))),
      border(`px(1), `solid, Style.Colors.hyperlink),
      borderRadius(`px(6)),
      maxWidth(`rem(18.75)),
      marginTop(`rem(0.625)),
      hover([
        opacity(0.9),
        backgroundColor(Style.Colors.azureAlpha(0.2)),
        border(`px(1), `solid, Style.Colors.hyperlinkHover),
        cursor(`pointer),
      ]),
    ]);

  let ctaContent =
    style([
      display(`flex),
      selector("p", [fontSize(`px(29)), marginTop(`rem(0.4375))]),
    ]);

  let ctaText = style([marginLeft(`rem(0.625))]);

  let ctaHeading =
    style([
      Style.Typeface.ibmplexsans,
      fontWeight(`num(600)),
      fontSize(`rem(1.5)),
      lineHeight(`rem(2.1875)),
      color(Style.Colors.teal),
      textAlign(`left),
    ]);

  let ctaBody =
    style([
      Style.Typeface.ibmplexsans,
      fontStyle(`normal),
      fontWeight(`normal),
      fontSize(`px(13)),
      color(Style.Colors.teal),
      textAlign(`left),
      marginTop(`rem(0.3125)),
    ]);

  let ctaIcon = style([minWidth(`px(29)), flexShrink(0)]);
};

[@react.component]
let make = (~icon, ~heading, ~text, ~href) => {
  <a href>
    <button className=Styles.ctaButton>
      <div className=Styles.ctaContent>
        <p className=Styles.ctaIcon> icon </p>
        <div className=Styles.ctaText>
          <h2 className=Styles.ctaHeading> heading </h2>
          <h4 className=Styles.ctaBody> text </h4>
        </div>
      </div>
    </button>
  </a>;
};
