module Colors = {
  let string =
    fun
    | `rgb(r, g, b) => Printf.sprintf("rgb(%d,%d,%d)", r, g, b)
    | `rgba(r, g, b, a) => Printf.sprintf("rgba(%d,%d,%d,%f)", r, g, b, a)
    | `hsl(h, s, l) => Printf.sprintf("hsl(%d,%d%%,%d%%)", h, s, l)
    | `hsla(h, s, l, a) =>
      Printf.sprintf("hsla(%d,%d%%,%d%%,%f)", h, s, l, a);

  let fadedBlue = `rgb((111, 167, 197));
  let white = Css.white;
  let whiteAlpha = a => `rgba((255, 255, 255, a));
  let hyperlink = `hsl((201, 71, 52));
  let hyperlinkAlpha = a => `hsla((201, 71, 52, a));
  let hyperlinkHover = `hsl((201, 71, 40));
  let hyperlinkLight = `hsl((201, 71, 70));

  let metallicBlue = `rgb((70, 99, 131));
  let denimTwo = `rgb((61, 88, 120));
  let greyBlue = `rgb((118, 147, 190));
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
  let navyBlue = `rgb((0, 23, 74));
  let navyBlueAlpha = a => `rgba((0, 23, 74, a));
  let greyishAlpha = a => `rgba((170, 170, 170, a));
  let saville = `hsl((212, 33, 35));

  let clover = `rgb((22, 168, 85));
  let lightClover = `rgba((118, 205, 135, 0.12));

  let teal = `rgb((71, 130, 160));
  let tealBlue = `rgb((0, 170, 170));
  let tealAlpha = a => `rgba((71, 130, 160, a));

  let rosebud = `rgb((163, 83, 111));
  let rosebudAlpha = a => `rgba((163, 83, 111, a));

  let blueBlue = `rgb((42, 81, 224));
  let midnight = `rgb((31, 45, 61));

  let india = `rgb((242, 183, 5));
  let indiaAlpha = a => `rgba((242, 183, 5, a));

  let amber = `rgb((242, 149, 68));
  let amberAlpha = a => `rgba((242, 149, 68, a));

  let marine = `rgb((51, 104, 151));
  let marineAlpha = a => `rgba((51, 104, 151, a));

  let jungleAlpha = a => `rgba((47, 172, 70, a));
  let jungle = jungleAlpha(1.);
};

module Typeface = {
  open Css;

  let cdnUrl = u => url(Links.Cdn.url(u));

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

  let load = () => {
    let () =
      List.iter(
        ((weight, name)) =>
          ignore @@
          fontFace(
            ~fontFamily="IBM Plex Sans",
            ~src=[
              cdnUrl("/static/font/IBMPlexSans-" ++ name ++ "-Latin1.woff2"),
              cdnUrl("/static/font/IBMPlexSans-" ++ name ++ "-Latin1.woff"),
            ],
            ~fontStyle=`normal,
            ~fontWeight=weight,
            (),
          ),
        weights,
      );

    let _ =
      fontFace(
        ~fontFamily="IBM Plex Mono",
        ~src=[
          cdnUrl("/static/font/IBMPlexMono-Medium-Latin1.woff2"),
          cdnUrl("/static/font/IBMPlexMono-Medium-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`semiBold,
        (),
      );

    let _ =
      fontFace(
        ~fontFamily="IBM Plex Mono",
        ~src=[
          cdnUrl("/static/font/IBMPlexMono-SemiBold-Latin1.woff2"),
          cdnUrl("/static/font/IBMPlexMono-SemiBold-Latin1.woff"),
        ],
        ~fontStyle=`normal,
        ~fontWeight=`bold,
        (),
      );

    let _ =
      fontFamily(
        fontFace(
          ~fontFamily="IBM Plex Serif",
          ~src=[
            cdnUrl("/static/font/IBMPlexSerif-Medium-Latin1.woff2"),
            cdnUrl("/static/font/IBMPlexSerif-Medium-Latin1.woff"),
          ],
          ~fontStyle=`normal,
          ~fontWeight=`medium,
          (),
        ),
      );
    ();

    // Workaround to allow the website to be build for dev
    // without needing the pragmatapro font.
    // If you have the font asset, it will be used.
    if (Node.Fs.existsSync(
          Links.Cdn.localAssetPath(
            "/static/font/Essential-PragmataPro-Regular.woff2",
          ),
        )
        || Config.isProd) {
      let _ =
        fontFamily(
          fontFace(
            ~fontFamily="PragmataPro",
            ~src=[
              cdnUrl("/static/font/Essential-PragmataPro-Regular.woff2"),
              cdnUrl("/static/font/Essential-PragmataPro-Regular.woff"),
            ],
            ~fontStyle=`normal,
            ~fontWeight=`medium,
            (),
          ),
        );

      let _ =
        fontFamily(
          fontFace(
            ~fontFamily="PragmataPro",
            ~src=[
              cdnUrl("/static/font/Essential-PragmataPro-Bold.woff2"),
              cdnUrl("/static/font/Essential-PragmataPro-Bold.woff"),
            ],
            ~fontStyle=`normal,
            ~fontWeight=`bold,
            (),
          ),
        );
      ();
    } else {
      print_endline("Warning: building without PragmataPro fonts");
    };
  };

  let ibmplexserif = fontFamily("IBM Plex Serif, serif");

  let ibmplexsans =
    fontFamily("IBM Plex Sans, Helvetica Neue, Arial, sans-serif");

  let ibmplexmono = fontFamily("IBM Plex Mono, Menlo, monospace");

  let aktivgrotesk = fontFamily("aktiv-grotesk-extended, sans-serif");

  let rubik = fontFamily("Rubik, sans-serif");

  let pragmataPro = fontFamily("PragmataPro, monospace");
};

module MediaQuery = {
  let veryVeryLarge = "(min-width: 77rem)";
  let veryLarge = "(min-width: 70.8125rem)";
  let somewhatLarge = "(min-width: 65.5rem)";
  let full = "(min-width: 54rem)";
  let notMobile = "(min-width: 32rem)";
  let notSmallMobile = "(min-width: 25rem)";
  let statusLiftAlways = "(min-width: 38rem)";
  let statusLift = keepAnnouncementBar =>
    keepAnnouncementBar ? statusLiftAlways : "(min-width: 0rem)";

  // to adjust root font size (therefore pixels)
  let iphoneSEorSmaller = "(max-width: 374px)";
};

/** sets both paddingLeft and paddingRight, as one should */
let paddingX = m => Css.[paddingLeft(m), paddingRight(m)];

/** sets both paddingTop and paddingBottom, as one should */
let paddingY = m => Css.[paddingTop(m), paddingBottom(m)];

let generateStyles = rules => (Css.style(rules), rules);

module Link = {
  open Css;

  let (init, basicStyles) =
    generateStyles([
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

  let (hero, heroStyles) =
    generateStyles([
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

module H2 = {
  open Css;

  let (basic, basicStyles) =
    generateStyles([
      Typeface.ibmplexsans,
      fontWeight(`normal),
      fontSize(`rem(2.25)),
      letterSpacing(`rem(-0.03125)),
      lineHeight(`rem(3.0)),
    ]);
};

module Technical = {
  open Css;
  let border = f => style([f(`px(3), `dashed, Colors.greyishAlpha(0.5))]);

  let basic =
    style([
      Typeface.pragmataPro,
      fontWeight(`normal),
      color(Css.white),
      fontSize(`rem(0.9375)),
      textTransform(`uppercase),
    ]);
};

module H3 = {
  open Css;

  let (basic, basicStyles) =
    generateStyles([
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

  module Technical = {
    let basic =
      style([
        Typeface.pragmataPro,
        fontSize(`rem(0.9375)),
        fontWeight(`bold),
        letterSpacing(`px(1)),
        textTransform(`uppercase),
      ]);

    let title = merge([basic, style([color(Css.black)])]);

    let boxed =
      merge([
        basic,
        Technical.border(Css.border),
        style([
          color(Colors.white),
          lineHeight(`rem(1.5)),
          display(`inlineFlex),
          justifyContent(`center),
          alignItems(`center),
          minWidth(`rem(9.0625)),
          height(`rem(3.)),
          margin(`auto),
          whiteSpace(`nowrap),
          padding2(~v=`zero, ~h=`rem(1.)),
        ]),
      ]);
  };
};

module H4 = {
  open Css;

  let (basic, basicStyles) =
    generateStyles([
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

  let (wide, wideStyles) =
    generateStyles([
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

  module Technical = {
    let (basic, basicStyles) =
      generateStyles([
        Typeface.pragmataPro,
        color(Css.white),
        fontSize(`rem(1.)),
        lineHeight(`rem(1.25)),
        letterSpacing(`rem(0.00625)),
      ]);
  };

  let (basic, basicStyles) =
    generateStyles([
      Typeface.ibmplexsans,
      color(Colors.saville),
      fontSize(`rem(1.0)),
      lineHeight(`rem(1.5)),
      fontWeight(`normal),
    ]);

  let basic_semibold = merge([basic, style([fontWeight(`semiBold)])]);

  let big =
    style([
      Typeface.ibmplexsans,
      color(Colors.darkGreyBlue),
      fontSize(`rem(1.125)),
      lineHeight(`rem(1.875)),
    ]);

  let big_semibold = merge([big, style([fontWeight(`semiBold)])]);

  let small =
    style([
      Typeface.ibmplexsans,
      fontSize(`rem(0.8125)),
      opacity(0.5),
      lineHeight(`rem(1.25)),
    ]);
};

// Match Tachyons setting pretty much everything to border-box
Css.global(
  "a,article,aside,blockquote,body,code,dd,div,dl,dt,fieldset,figcaption,figure,footer,form,h1,h2,h3,h4,h5,h6,header,html,input[type=email],input[type=number],input[type=password],input[type=tel],input[type=text],input[type=url],legend,li,main,nav,ol,p,pre,section,table,td,textarea,th,tr,ul",
  [Css.boxSizing(`borderBox)],
);

// Reset padding that appears only on some browsers
Css.global(
  "h1,h2,h3,h4,h5,fieldset,ul,li,p",
  Css.[
    unsafe("padding-inline-start", "0"),
    unsafe("padding-inline-end", "0"),
    unsafe("padding-block-start", "0"),
    unsafe("padding-block-end", "0"),
    unsafe("margin-inline-start", "0"),
    unsafe("margin-inline-end", "0"),
    unsafe("margin-block-start", "0"),
    unsafe("margin-block-end", "0"),
    unsafe("-webkit-padding-before", "0"),
    unsafe("-webkit-padding-start", "0"),
    unsafe("-webkit-padding-end", "0"),
    unsafe("-webkit-padding-after", "0"),
    unsafe("-webkit-margin-before", "0"),
    unsafe("-webkit-margin-after", "0"),
  ],
);

Css.global("p", Css.[marginTop(`rem(1.)), marginBottom(`rem(1.))]);