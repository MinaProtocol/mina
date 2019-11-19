module Styles = {
  open Css;

  let ctaButton =
    style([
      background(Style.Colors.lightBlue(0.1)),
      borderRadius(`px(6)),
      textDecoration(`none),
      padding(`rem(2.0)),
      margin(`auto),
      height(`rem(13.)),
      width(`percent(80.)),
      media("(min-width: 35rem)", [height(`rem(10.)), width(`rem(29.))]),
      media("(min-width: 50rem)", [height(`rem(11.)), width(`rem(23.))]),
      media("(min-width: 75rem)", [height(`rem(10.)), width(`rem(35.))]),
      hover([
        backgroundColor(`hex("FAFCFD")),
        cursor(`pointer),
        boxShadow(
          ~x=`zero,
          ~y=`px(4),
          ~blur=`px(8),
          ~spread=`zero,
          `rgba((0, 0, 0, 0.25)),
        ),
        selector("svg", [SVG.fill(Style.Colors.hyperlink)]),
      ]),
    ]);

  let ctaContent =
    style([display(`flex), selector("p", [fontSize(`px(36))])]);

  let ctaText = style([width(`percent(100.)), marginLeft(`px(13))]);

  let ctaHeading =
    merge([
      Style.H2.basic,
      style([
        Style.Typeface.ibmplexsans,
        color(Style.Colors.marine),
        textAlign(`left),
        paddingBottom(`rem(0.3)),
      ]),
    ]);

  let ctaBody = Style.Body.basic;

  let ctaIcon =
    style([
      marginTop(`px(2)),
      minWidth(`px(36)),
      maxHeight(`px(48)),
      flexShrink(0),
    ]);
  let arrow =
    style([
      marginTop(`rem(1.0)),
      marginLeft(`rem(1.0)),
      SVG.fill(Style.Colors.hyperlinkAlpha(0.5)),
    ]);

  let headingRow =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
    ]);
};

[@react.component]
let make = (~heading, ~text, ~href) => {
  <a href className=Styles.ctaButton>
    <div className=Styles.ctaContent>
      <div className=Styles.ctaText>
        <div className=Styles.headingRow>
          <h2 className=Styles.ctaHeading> heading </h2>
          <svg
            className=Styles.arrow
            width="27"
            height="17"
            viewBox="0 0 27 17"
            xmlns="http://www.w3.org/2000/svg">
            <path
              d="M17.7329 16.716L15.1769 14.16L17.6249 11.712L19.2809 10.308L19.2449 10.164L16.1849 10.344H0.452881V6.52801H16.1849L19.2449 6.70801L19.2809 6.56401L17.6249 5.16001L15.1769 2.71201L17.7329 0.156006L26.0129 8.43601L17.7329 16.716Z"
            />
          </svg>
        </div>
        <h4 className=Styles.ctaBody> text </h4>
      </div>
    </div>
  </a>;
};
