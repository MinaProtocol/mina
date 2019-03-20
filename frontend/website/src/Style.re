module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
  let white = Css.white;
  let hyperlink = `hsl((201, 71, 52));
  let hyperlinkAlpha = a => `hsla((201, 71, 52, a));
  let hyperlinkHover = `hsl((201, 71, 70));

  let metallicBlue = `rgb((70, 99, 131));
  let denimTwo = `rgb((61, 88, 120));
  let darkGreyBlue = `rgb((61, 88, 120));
  let greyishBrown = `rgb((74, 74, 74));

  let bluishGreen = `rgb((22, 168, 85));
  let purpleBrown = `rgb((100, 46, 48));
  let offWhite = `rgb((243, 243, 243));
  let grey = `rgb((129, 146, 168));

  let azure_01 = `rgba((45, 158, 219, 0.1));
  let gandalf = `rgb((243, 243, 243));

  let slate = `rgb((81, 102, 121));

  let navy = `rgb((0, 49, 90));
  let saville = `hsl((212, 33, 35));
  // For use with box-shadow so we can't use opacity
  let greenShadow = `rgba((136, 191, 163, 0.64));
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
  let notMobile = "(min-width: 32rem)";
};

/** sets both paddingLeft and paddingRight, as one should */
let paddingX = m => Css.[paddingLeft(m), paddingRight(m)];

/** sets both paddingTop and paddingBottom, as one should */
let paddingY = m => Css.[paddingTop(m), paddingBottom(m)];

module Link = {
  open Css;

  let init =
    style([
      Typeface.ibmplexsans,
      color(Colors.hyperlink),
      textDecoration(`none),
      fontWeight(`medium),
      fontSize(`rem(1.0)),
      letterSpacing(`rem(-0.0125)),
      lineHeight(`rem(1.5)),
    ]);

  module No_hover = {
    let basic = init;
  };

  let basic =
    merge([init, style([hover([color(Colors.hyperlinkHover)])])]);
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

  let wide =
    style([
      whiteSpace(`nowrap),
      fontSize(`rem(1.0)),
      color(Colors.fadedBlue),
      letterSpacing(`em(0.25)),
      Typeface.aktivgrotesk,
      fontWeight(`medium),
      fontStyle(`normal),
      textAlign(`center),
      textTransform(`uppercase),
    ]);

  let wings = {
    let wing = [
      contentRule(""),
      fontSize(`px(5)),
      verticalAlign(`top),
      lineHeight(`rem(1.3)),
      borderTop(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
      borderBottom(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
      ...paddingX(`rem(1.5)),
    ];

    merge([
      wide,
      style([
        before([marginRight(`rem(2.0)), ...wing]),
        after([marginLeft(`rem(2.0)), ...wing]),
      ]),
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

module H5 = {
  open Css;

  let basic =
    style([
      Typeface.ibmplexsans,
      textAlign(`center),
      fontSize(`rem(0.9345)),
      lineHeight(`rem(1.5)),
      letterSpacing(`rem(0.125)),
      fontWeight(`normal),
      opacity(50.0),
      color(`rgb((74, 74, 74))),
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
      fontWeight(`normal),
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

// Match Tachyons setting pretty much everything to border-box
Css.global(
  "a,article,aside,blockquote,body,code,dd,div,dl,dt,fieldset,figcaption,figure,footer,form,h1,h2,h3,h4,h5,h6,header,html,input[type=email],input[type=number],input[type=password],input[type=tel],input[type=text],input[type=url],legend,li,main,nav,ol,p,pre,section,table,td,textarea,th,tr,ul",
  [Css.boxSizing(`borderBox)],
);
