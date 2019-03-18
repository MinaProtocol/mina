module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
  let white = Css.white;
  let hyperlink = `hsl((201, 71, 52));
  let hyperlinkHover = `hsl((201, 71, 70));

  let metallicBlue = `rgb((70, 99, 131));
};

module Typeface = {
  open Css;

  let ibmplexsans = fontFamily("IBMPlexSans, Helvetica, sans-serif");
  let aktivgrotesk = fontFamily("aktiv-grotesk-extended, sans-serif");
};

module MediaQuery = {
  let full = "(min-width: 48rem)";
};

/** sets both paddingLeft and paddingRight, as one should */
let paddingX = m => Css.[paddingLeft(m), paddingRight(m)];

/** sets both paddingTop and paddingBottom, as one should */
let paddingY = m => Css.[paddingTop(m), paddingBottom(m)];

module Link = {
  open Css;

  let style =
    style([
      Typeface.ibmplexsans,
      color(Colors.hyperlink),
      fontWeight(`medium),
      fontSize(`rem(1.0)),
      letterSpacing(`rem(-0.0125)),
      lineHeight(`rem(1.5)),
      hover([color(Colors.hyperlinkHover)]),
    ]);
};

module H3 = {
  open Css;

  let wide = {
    let wing = [
      contentRule(" "),
      marginLeft(`rem(0.25)),
      fontSize(`px(5)),
      verticalAlign(`top),
      lineHeight(`rem(1.3)),
      borderTop(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
      borderBottom(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
      ...paddingX(`rem(3.0)),
    ];

    merge([
      style([
        fontSize(`rem(1.0)),
        color(Colors.fadedBlue),
        letterSpacing(`em(0.25)),
        Typeface.aktivgrotesk,
        fontWeight(`medium),
        fontStyle(`normal),
        textAlign(`center),
        textTransform(`uppercase),
      ]),
      style([before(wing), after(wing)]),
    ]);
  };
};

module Body = {
  open Css;

  let style =
    style([
      Typeface.ibmplexsans,
      color(Colors.metallicBlue),
      fontSize(`rem(1.0)),
      lineHeight(`rem(1.5)),
    ]);
};
