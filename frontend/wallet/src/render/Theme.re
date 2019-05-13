/** Shared styles and colors */
open Css;

global("*", [boxSizing(`borderBox)]);

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

  let savilleAlpha = a => `rgba((31, 45, 61, a));
  let saville = savilleAlpha(1.);

  let hyperlinkAlpha = a => `rgba((45, 158, 219, a));

  let slateAlpha = a => `rgba((81, 102, 121, a));

  let roseBud = `hex("a3536f");

  let serpentine = `hex("479056");
  let serpentineLight = `rgba((101, 144, 110, 0.2));

  let yeezy = `hex("C53131");

  let midnight = `hex("1F2D3D");
  let marineAlpha = a=> `rgba((51, 104, 151, a));
  let jungle = `hex("2BAC46");
  let sage = `hex("65906e");
  let blanco = `hex("e3e0d5");
  let modalDisableBgAlpha = a => `rgba((31, 45, 61, a));

  let headerBgColor = white;
  let headerGreyText = `hex("516679");
  let textColor = white;
  let borderColor = rgba(0, 0, 0, 0.15);
};

module Typeface = {
  let lucidaGrande = fontFamily("LucidaGrande");
  let plex = fontFamily("IBM Plex Sans, Sans-Serif");
  let mono = fontFamily("OCR A Std, monospace");
};

module Text = {
  let body =
    style([
      Typeface.plex,
      fontWeight(`medium),
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
    ]);

  let smallHeader =
    style([
      Typeface.plex,
      fontWeight(`normal),
      fontSize(`rem(0.75)),
      lineHeight(`rem(1.)),
    ]);

  let mono =
    style([
      Typeface.mono,
      fontWeight(`medium),
      fontSize(`rem(1.)),
      lineHeight(`rem(1.5)),
      // Due to the font weirdness, we need to offset by 4px
      paddingTop(`px(4)),
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
  let modalWidth = `rem(20.);
};

let notText = style([cursor(`default), userSelect(`none)]);

let codaLogoCurrent =
  style([
    width(`px(20)),
    height(`px(20)),
    backgroundColor(`hex("516679")),
    margin(`em(0.5)),
  ]);
