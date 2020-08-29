open Css;

module Colors = {
  let orange = `hex("ff603b");
  let mint = `hex("9fe4c9");
  let gray = `hex("d9d9d9");
  let white = Css.white;
  let black = Css.black;
  let purple = `hex("5362C8");
};

module Typeface = {
  let _ = {
    [
      fontFace(
        ~fontFamily="Monument Grotesk",
        ~src=[
          `url("fonts/IBMPlexSans-Regular-Latin1.woff2"),
          `url("fonts/IBMPlexSans-Regular-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`normal,
        (),
      ),
      fontFace(
        ~fontFamily="Monument Grotesk mono",
        ~src=[
          `url("fonts/IBMPlexSans-Regular-Latin1.woff2"),
          `url("fonts/IBMPlexSans-Regular-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`normal,
        (),
      ),
    ];
  };
  let monumentGrotesk = fontFamily("Monument Grotesk, serif");
  let monumentGroteskMono = fontFamily("Monument Grotesk mono, serif");
};

module MediaQuery = {
  let tablet = "(min-width:48rem)";
  let desktop = "(min-width:90rem)";

  /** to add a style to tablet and desktop, but not mobile */
  let notMobile = "(min-width:23.5rem)";

  /** to add a style just to mobile  */
  let mobile = "(max-width:48rem)";
};

/** this function is needed to include the font files with the font styles */
let generateStyles = rules => (Css.style(rules), rules);

module Type = {
  let h1jumbo =
    style([
      Typeface.monumentGrotesk,
      fontWeight(`normal),
      fontSize(`rem(3.5)),
      lineHeight(`rem(4.1875)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(4.5)), lineHeight(`rem(5.4))],
      ),
    ]);

  let h1 =
    style([
      Typeface.monumentGrotesk,
      fontWeight(`normal),
      fontSize(`rem(2.25)),
      lineHeight(`rem(2.7)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(3.0)), lineHeight(`rem(3.6))],
      ),
    ]);

  let h2 =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.875)),
      lineHeight(`rem(2.25)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(2.5)), lineHeight(`rem(3.))],
      ),
    ]);

  let h3 =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.6)),
      lineHeight(`rem(2.1)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(2.0)), lineHeight(`rem(2.375))],
      ),
    ]);

  /** initially named "h4MonoAllCaps",
   * but cut to h4 for brevity since we currently don't have another h4 style
   */
  let h4 =
    style([
      Typeface.monumentGroteskMono,
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.7)),
      textTransform(`uppercase),
      letterSpacing(`em(0.02)),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.25)), lineHeight(`rem(1.9))],
      ),
    ]);

  let h5 =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.3)),
      lineHeight(`rem(1.56)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.5)), lineHeight(`rem(1.8))],
      ),
    ]);

  let h6 =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.375)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.125)), lineHeight(`rem(1.4))],
      ),
    ]);

  /** the following are specific component names, but use some styles already defined  */
  let pageLabel =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(0.9)),
      lineHeight(`rem(1.37)),
      textTransform(`uppercase),
      letterSpacing(`em(0.02)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.25)), lineHeight(`rem(1.875))],
      ),
    ]);

  let label =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(0.75)),
      lineHeight(`rem(1.)),
      color(black),
      textTransform(`uppercase),
      letterSpacing(`em(0.03)),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(0.88)), lineHeight(`rem(1.))],
      ),
    ]);

  let buttonLabel =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(0.75)),
      fontWeight(`num(500)),
      lineHeight(`rem(1.)),
      color(black),
      textTransform(`uppercase),
      letterSpacing(`px(1)),
    ]);

  let link =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.7)),
      color(Colors.orange),
      hover([textDecoration(`underline)]),
    ]);

  let navLink =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.1)),
      lineHeight(`rem(1.1)),
      color(black),
    ]);

  let sidebarLink =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
      color(black),
    ]);

  let tooltip =
    style([
      Typeface.monumentGrotesk,
      fontSize(`px(13)),
      lineHeight(`rem(1.)),
      color(black),
    ]);

  let creditName =
    style([
      Typeface.monumentGrotesk,
      fontSize(`px(10)),
      lineHeight(`rem(1.)),
      letterSpacing(`em(-0.01)),
    ]);

  let metadata =
    style([
      Typeface.monumentGrotesk,
      fontSize(`px(12)),
      lineHeight(`rem(1.)),
      letterSpacing(`em(0.05)),
      textTransform(`uppercase),
    ]);

  let announcement =
    style([
      Typeface.monumentGrotesk,
      fontWeight(`num(500)),
      fontSize(`px(14)),
      lineHeight(`rem(1.5)),
    ]);

  let errorMessage =
    style([
      Typeface.monumentGrotesk,
      fontSize(`px(13)),
      lineHeight(`rem(1.)),
      color(`hex("e93939")),
    ]);

  let pageSubhead =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.68)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.31)), lineHeight(`rem(1.93))],
      ),
    ]);

  let sectionSubhead =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
      letterSpacing(`px(-1)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.25)), lineHeight(`rem(1.875))],
      ),
    ]);

  let paragraph =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.125)), lineHeight(`rem(1.69))],
      ),
    ]);

  let paragraphSmall =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(0.875)),
      lineHeight(`rem(1.31)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(1.)), lineHeight(`rem(1.5))],
      ),
    ]);

  let paragraphMono =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
      letterSpacing(`rem(0.03125)),
      color(black),
      media(
        MediaQuery.tablet,
        [
          fontSize(`rem(1.)),
          lineHeight(`rem(1.5)),
          letterSpacing(`px(-1)),
        ],
      ),
    ]);

  let quote =
    style([
      Typeface.monumentGrotesk,
      fontSize(`rem(1.31)),
      lineHeight(`rem(1.875)),
      letterSpacing(`em(-0.03)),
      color(black),
      media(
        MediaQuery.tablet,
        [fontSize(`rem(2.5)), lineHeight(`rem(3.125))],
      ),
    ]);
};
