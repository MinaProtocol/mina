module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
  let white = `rgb((255, 255, 255));
};

/** sets both paddingLeft and paddingRight, as one should */
let paddingX = m => Css.[paddingLeft(m), paddingRight(m)];

/** sets both paddingTop and paddingBottom, as one should */
let paddingY = m => Css.[paddingTop(m), paddingBottom(m)];

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
        fontFamily("aktiv-grotesk-extended, sans-serif"),
        fontWeight(`medium),
        fontStyle(`normal),
        textAlign(`center),
        textTransform(`uppercase),
      ]),
      style([before(wing), after(wing)]),
    ]);
  };
};
