/** Shared styles and colors */
open Css;

module Colors = {
  let hexToString = (`hex(s)) => s;

  let bgColor = `hex("121F2B");
  let savilleAlpha = a => `rgba((31, 45, 61, a));
  let saville = savilleAlpha(1.);

  let serpentine = `hex("479056");

  let roseBud = `hex("a3536f");

  let sage = `hex("65906e");

  let headerBgColor = `hex("06111bBB");
  let headerGreyText = `hex("516679");
  let textColor = white;
};

module Typeface = {
  let lucidaGrande = fontFamily("LucidaGrande");
};

module CssElectron = {
  let appRegion =
    fun
    | `drag => `declaration(("-webkit-app-region", "drag"))
    | `noDrag => `declaration(("-webkit-app-region", "no-drag"));
};

let notText = style([cursor(`default), userSelect(`none)]);

let codaLogoCurrent =
  style([
    width(`px(20)),
    height(`px(20)),
    backgroundColor(`hex("516679")),
    margin(`em(0.5)),
  ]);
