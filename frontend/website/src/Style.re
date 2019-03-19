module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
  let white = Css.white;
  let hyperlink = `hsl((201, 71, 52));
  let hyperlinkHover = `hsl((201, 71, 70));

  let metallicBlue = `rgb((70, 99, 131));
  let denimTwo = `rgb((61, 88, 120));
  let darkGreyBlue = `rgb((61, 88, 120));
  let greyishBrown = `rgb((74, 74, 74));

  let bluishGreen = `rgb((22, 168, 85));
  let purpleBrown = `rgb((100, 46, 48));
  let offWhite = `rgb((243, 243, 243));
  let grey = `rgb((129, 146, 168));

  let navy = `rgb((0, 49, 90));
};

module Typeface = {
  open Css;

  let ibmplexsans =
    fontFamily("IBM Plex Sans, Helvetica Neue, Arial, sans-serif");

  let ibmplexmono = fontFamily("IBM Plex Mono, Menlo, monospace");

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
      textDecoration(`none),
      fontWeight(`medium),
      fontSize(`rem(1.0)),
      letterSpacing(`rem(-0.0125)),
      lineHeight(`rem(1.5)),
      hover([color(Colors.hyperlinkHover)]),
    ]);
};

module H1 = {
  open Css;

  let hero =
    style([
      Typeface.ibmplexsans,
      fontWeight(`light),
      fontSize(`rem(2.25)),
      letterSpacing(`rem(-0.02375)),
      lineHeight(`rem(3.0)),
      color(Colors.denimTwo),
      media(
        MediaQuery.full,
        [
          fontSize(`rem(3.0)),
          letterSpacing(`rem(-0.03125)),
          lineHeight(`rem(4.0)),
        ],
      ),
    ]);
};

module H3 = {
  open Css;

  let basic =
    style([
      Typeface.ibmplexsans,
      fontSize(`rem(1.25)),
      textAlign(`center),
      lineHeight(`rem(1.5)),
    ]);

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

module H4 = {
  open Css;

  let basic =
    style([
      Typeface.ibmplexsans,
      textAlign(`center),
      fontSize(`rem(1.0625)),
      lineHeight(`rem(1.5)),
      letterSpacing(`rem(0.25)),
      opacity(50.0),
      textTransform(`uppercase),
      fontWeight(`normal),
      color(Colors.greyishBrown),
    ]);
};

module Body = {
  open Css;

  let basic =
    style([
      Typeface.ibmplexsans,
      color(Colors.metallicBlue),
      fontSize(`rem(1.0)),
      lineHeight(`rem(1.5)),
    ]);

  let big =
    style([
      Typeface.ibmplexsans,
      color(Colors.darkGreyBlue),
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.875)),
    ]);

  let big_semibold = merge([big, style([fontWeight(`semiBold)])]);
};
