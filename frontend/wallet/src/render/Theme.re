/** Shared styles and colors */
open Css;

global("*", [boxSizing(`borderBox), userSelect(`none)]);
global("h1, h2, h3, h4, h5", [margin(`zero)]);
global(
  "input[type=number]::-webkit-inner-spin-button, input[type=number]::-webkit-outer-spin-button",
  [margin(`zero), unsafe("-webkit-appearance", "none")],
);

module Colors = {
  let string =
    fun
    | `rgb(r, g, b) => Printf.sprintf("rgb(%d,%d,%d)", r, g, b)
    | `rgba(r, g, b, a) => Printf.sprintf("rgba(%d,%d,%d,%f)", r, g, b, a)
    | `hsl(h, s, l) => Printf.sprintf("hsl(%d,%d%%,%d%%)", h, s, l)
    | `hex(s) => Printf.sprintf("#%s", s)
    | `hsla(h, s, l, a) =>
      Printf.sprintf("hsla(%d,%d%%,%d%%,%f)", h, s, l, a);

  let bgColor = white;

  // Linux doesn't support transparency
  let bgColorElectronWindow = "#FFE9E9E9";

  let savilleAlpha = a => `rgba((61, 88, 120, a));
  let saville = savilleAlpha(1.);

  let hyperlinkAlpha = a => `rgba((45, 158, 219, a));
  let hyperlink = hyperlinkAlpha(1.);

  let slateAlpha = a => `rgba((81, 102, 121, a));
  let slate = slateAlpha(1.);

  let roseBudAlpha = a => `rgba((163, 83, 112, a));
  let roseBud = roseBudAlpha(1.);

  let pendingOrange = `hex("967103");
  let greenblack = `hex("2a3c2e");

  let serpentine = `hex("479056");
  let serpentineLight = `rgba((101, 144, 110, 0.2));

  let yeezyAlpha = a => `rgba((197, 49, 49, a));
  let yeezy = yeezyAlpha(1.0);

  let gandalfAlpha = a => `rgba((213, 212, 210, a));
  let gandalf = gandalfAlpha(1.);

  let clover = `rgb((71, 144, 86));
  let cloverAlpha = a => `rgba((71, 144, 86, a));

  let amberAlpha = a => `rgba((242, 149, 68, a));

  let mossAlpha = a => `rgba((101, 144, 110, a));

  let clay = `rgb((150, 113, 3));

  let marineAlpha = a => `rgba((51, 104, 151, a));
  let marine = marineAlpha(1.0);

  let midnightAlpha = a => `rgba((31, 45, 61, a));
  let midnight = midnightAlpha(1.0);

  let midnightBlue = `rgb((52, 75, 101));

  let jungle = `hex("2BAC46");
  let sage = `hex("65906e");
  let blanco = `hex("e3e0d5");
  let modalDisableBgAlpha = a => `rgba((31, 45, 61, a));

  let headerBgColor = white;
  let headerGreyText = `hex("516679");
  let textColor = white;
  let borderColor = rgba(0, 0, 0, 0.15);

  // TODO: Rename
  let greyish = a => `rgba((51, 66, 79, a));

  let tealAlpha = a => `rgba((71, 130, 160, a));
  let teal = tealAlpha(1.0);
};

module Typeface = {
  // fontFace has the sideEffect of loading the font
  let _ = {
    [
      fontFace(
        ~fontFamily="IBM Plex Sans",
        ~src=[
          `url("fonts/IBMPlexSans-SemiBold-Latin1.woff2"),
          `url("fonts/IBMPlexSans-SemiBold-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`semiBold,
        (),
      ),
      fontFace(
        ~fontFamily="IBM Plex Sans",
        ~src=[
          `url("fonts/IBMPlexSans-Medium-Latin1.woff2"),
          `url("fonts/IBMPlexSans-Medium-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`medium,
        (),
      ),
      fontFace(
        ~fontFamily="IBM Plex Sans",
        ~src=[
          `url("fonts/IBMPlexSans-Regular-Latin1.woff2"),
          `url("fonts/IBMPlexSans-Regular-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`normal,
        (),
      ),
      fontFace(
        ~fontFamily="OCR A Std",
        ~src=[`url("fonts/OCR A Std Regular.otf")],
        ~fontStyle=`normal,
        ~fontWeight=`normal,
        (),
      ),
    ];
  };

  let lucidaGrande = fontFamily("LucidaGrande");
  let plex = fontFamily("IBM Plex Sans, Sans-Serif");
  let mono = fontFamily("OCR A Std, monospace");
};

module Text = {
  module Body = {
    let regular =
      style([
        Typeface.plex,
        fontWeight(`medium),
        fontSize(`rem(1.)),
        lineHeight(`rem(1.5)),
      ]);
    let regularLight =
      style([
        Typeface.plex,
        fontWeight(`normal),
        fontSize(`rem(1.)),
        lineHeight(`rem(1.5)),
      ]);

    let mono =
      style([Typeface.mono, fontWeight(`medium), fontSize(`rem(0.9))]);

    let small =
      style([
        Typeface.plex,
        fontWeight(`normal),
        fontSize(`rem(0.8125)),
        lineHeight(`rem(1.25)),
        color(Colors.midnight),
      ]);

    let semiBold =
      style([
        Typeface.plex,
        fontWeight(`semiBold),
        fontSize(`rem(1.)),
        lineHeight(`rem(1.5)),
        letterSpacing(`rem(-0.0125)),
      ]);

    let smallCaps =
      style([
        Typeface.plex,
        fontWeight(`semiBold),
        fontSize(`rem(0.75)),
        lineHeight(`rem(1.0)),
        letterSpacing(`rem(0.0875)),
        textTransform(`uppercase),
      ]);
    let error =
      style([
        Typeface.plex,
        fontWeight(`semiBold),
        fontSize(`rem(1.)),
        letterSpacing(`rem(-0.0125)),
        color(Colors.roseBud),
      ]);
  };

  module Header = {
    let h1 =
      style([
        Typeface.plex,
        color(Colors.saville),
        fontSize(`rem(2.79)),
        fontWeight(`num(300)),
        lineHeight(`rem(3.73)),
      ]);
    let h3 =
      style([
        Typeface.plex,
        fontWeight(`medium),
        fontSize(`rem(1.25)),
        lineHeight(`rem(1.5)),
        letterSpacing(`rem(-0.03125)),
      ]);
    let h5 =
      style([
        Typeface.plex,
        fontWeight(`normal),
        fontSize(`rem(0.9345)),
        lineHeight(`rem(1.0)),
        letterSpacing(`rem(0.125)),
        textTransform(`uppercase),
      ]);
    let h6 =
      style([
        Typeface.plex,
        fontWeight(`medium),
        fontSize(`rem(0.75)),
        lineHeight(`rem(1.0)),
        letterSpacing(`rem(0.0875)),
      ]);
  };

  let title =
    style([
      Typeface.plex,
      fontWeight(`normal),
      fontSize(`rem(2.25)),
      lineHeight(`rem(3.)),
    ]);
};

module CssElectron = {
  let appRegion =
    fun
    | `drag => `declaration(("-webkit-app-region", "drag"))
    | `noDrag => `declaration(("-webkit-app-region", "no-drag"));
};

module Spacing = {
  let defaultSpacing = `rem(1.);
  let defaultPadding = padding(defaultSpacing);
  let headerHeight = `rem(4.);
  let footerHeight = `rem(5.);
  let modalWidth = `rem(26.);
};

let notText = style([cursor(`default), userSelect(`none)]);

let codaLogoCurrent =
  style([
    width(`px(20)),
    height(`px(20)),
    backgroundColor(`hex("516679")),
    margin(`em(0.5)),
  ]);

module Onboarding = {
  let main =
    merge([
      style([
        position(`absolute),
        top(`zero),
        left(`zero),
        background(white),
        zIndex(100),
        display(`flex),
        flexDirection(`row),
        paddingTop(Spacing.headerHeight),
        paddingBottom(Spacing.footerHeight),
        height(`vh(100.)),
        width(`vw(100.)),
      ]),
      Window.Styles.bg,
    ]);
};
