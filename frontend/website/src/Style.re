module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
  let white = Css.white;
  let whiteAlpha = a => `rgba((255, 255, 255, a));
  let hyperlink = `hsl((201, 71, 52));
  let hyperlinkString = "hsl(201, 71%, 52%)";
  let hyperlinkAlpha = a => `hsla((201, 71, 52, a));
  let hyperlinkHover = `hsl((201, 71, 40));

  let metallicBlue = `rgb((70, 99, 131));
  let denimTwo = `rgb((61, 88, 120));
  let darkGreyBlue = `rgb((61, 88, 120));
  let greyishBrown = `rgb((74, 74, 74));

  let bluishGreen = `rgb((22, 168, 85));
  let offWhite = `rgb((243, 243, 243));
  let grey = `rgb((129, 146, 168));

  let azureAlpha = a => `rgba((45, 158, 219, a));
  let gandalf = `rgb((243, 243, 243));
  let veryLightGrey = `rgb((235, 235, 235));

  let slate = `hsl((209, 20, 40));
  let slateAlpha = a => `hsla((209, 20, 40, a));

  let navy = `rgb((0, 49, 90));
  let saville = `hsl((212, 33, 35));
  // For use with box-shadow so we can't use opacity
  let greenShadow = `rgba((136, 191, 163, 0.64));

  let clover = `rgb((22, 168, 85));
  let lightClover = `rgba((118, 205, 135, 0.12));

  let teal = `rgb((71, 130, 160));
  let tealAlpha = a => `rgba((71, 130, 160, a));

  let rosebud = `rgb((163, 83, 111));

  let blueBlue = `rgb((42, 81, 224));
  let midnight = `rgb((31, 45, 61));
};

module Typeface = {
  open Css;
  // To prevent "flash of unstyled text" on some browsers (firefox), we need
  // to do insane things to mitigate it. Even though the CSS working group
  // created `font-display: block` for this purpose, Firefox chooses to not
  // follow the standard "wait for 3seconds before showing fallback fonts."
  //
  // Instead we can base64 the woff and woff2 fonts and include those directly
  // in our stylesheets. Now those browsers have no choice but to show us the
  // font correctly.
  //
  // Scafolding code adapted from Bs-css Css.re.
  module Loader = {
    let string_of_fontWeight = x =>
      switch (x) {
      | `thin => "100"
      | `extraLight => "200"
      | `light => "300"
      | `normal => "400"
      | `medium => "500"
      | `semiBold => "600"
      | `bold => "700"
      | `extraBold => "800"
      };

    let genFontFace = (~fontFamily, ~src, ~fontWeight=?, ()) => {
      let src =
        src
        |> List.map(s => {
             let ext = {
               let arr = Js.String.split(".", s);
               arr[Array.length(arr) - 1];
             };
             let b64 = Node.Fs.readFileSync("./" ++ s, `base64);
             "url(\"data:font/"
             ++ ext
             ++ ";base64,"
             ++ b64
             ++ "\") format(\""
             ++ ext
             ++ "\")";
           })
        |> String.concat(", ");

      let fontWeight =
        Belt.Option.mapWithDefault(fontWeight, "", w =>
          "font-weight: " ++ string_of_fontWeight(w)
        );
      let asString = {j|@font-face {
      font-family: $fontFamily;
      src: $src;
      font-display: block;
      font-style: normal;
      $(fontWeight);
  }|j};

      asString;
    };

    let load = () => {
      let weights = [
        // The weights are intentionally shifted thinner one unit
        (`thin, "Thin"),
        (`extraLight, "Thin"),
        (`light, "ExtraLight"),
        (`normal, "Light"),
        (`medium, "Regular"),
        (`semiBold, "Medium"),
        (`bold, "SemiBold"),
        (`extraBold, "Bold"),
      ];

      String.concat(
        "\n",
        [
          genFontFace(
            ~fontFamily="IBM Plex Serif",
            ~src=[
              "/static/font/IBMPlexSerif-Medium-Latin1.woff2",
              "/static/font/IBMPlexSerif-Medium-Latin1.woff",
            ],
            ~fontWeight=`medium,
            (),
          ),
          genFontFace(
            ~fontFamily="IBM Plex Mono",
            ~src=[
              "/static/font/IBMPlexMono-SemiBold-Latin1.woff2",
              "/static/font/IBMPlexMono-SemiBold-Latin1.woff",
            ],
            ~fontWeight=`bold,
            (),
          ),
          genFontFace(
            ~fontFamily="IBM Plex Mono",
            ~src=[
              "/static/font/IBMPlexMono-Medium-Latin1.woff2",
              "/static/font/IBMPlexMono-Medium-Latin1.woff",
            ],
            ~fontWeight=`semiBold,
            (),
          ),
          ...List.map(
               ((weight, name)) =>
                 genFontFace(
                   ~fontFamily="IBM Plex Sans",
                   ~src=[
                     "/static/font/IBMPlexSans-" ++ name ++ "-Latin1.woff2",
                     "/static/font/IBMPlexSans-" ++ name ++ "-Latin1.woff",
                   ],
                   ~fontWeight=weight,
                   (),
                 ),
               weights,
             ),
        ],
      );
    };
  };

  let ibmplexserif = fontFamily("IBM Plex Serif, serif");

  let ibmplexsans =
    fontFamily("IBM Plex Sans, Helvetica Neue, Arial, sans-serif");

  let ibmplexmono = fontFamily("IBM Plex Mono, Menlo, monospace");

  let aktivgrotesk = fontFamily("aktiv-grotesk-extended, sans-serif");

  let rubik = fontFamily("Rubik, sans-serif");
};

module MediaQuery = {
  let veryLarge = "(min-width: 71rem)";
  let full = "(min-width: 48rem)";
  let notMobile = "(min-width: 32rem)";
  let notSmallMobile = "(min-width: 25rem)";
  // to adjust root font size (therefore pixels)
  let iphoneSEorSmaller = "(max-width: 374px)";
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

  let wideNoColor =
    style([
      whiteSpace(`nowrap),
      fontSize(`rem(1.0)),
      letterSpacing(`em(0.25)),
      Typeface.aktivgrotesk,
      fontWeight(`medium),
      fontStyle(`normal),
      textAlign(`center),
      textTransform(`uppercase),
    ]);

  let wide = merge([wideNoColor, style([color(Colors.fadedBlue)])]);

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

  let wide =
    style([
      whiteSpace(`nowrap),
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.125)),
      Typeface.aktivgrotesk,
      fontWeight(`medium),
      fontStyle(`normal),
      textAlign(`center),
      textTransform(`uppercase),
    ]);
};

module H5 = {
  open Css;

  let init =
    style([
      Typeface.ibmplexsans,
      fontSize(`rem(0.9345)),
      letterSpacing(`rem(0.125)),
      fontWeight(`normal),
      color(Colors.slateAlpha(0.5)),
      textTransform(`uppercase),
    ]);

  let basic = merge([init, style([lineHeight(`rem(1.5))])]);

  let tight = merge([init, style([lineHeight(`rem(1.25))])]);
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
