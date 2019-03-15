module Colors = {
  let fadedBlue = `rgb((111, 167, 197));
};

module H3 = {
  open Css;

  let wide = {
    let wing = [
      contentRule(" "),
      paddingLeft(`rem(3.0)),
      paddingRight(`rem(3.0)),
      marginLeft(`rem(0.25)),
      fontSize(`px(5)),
      verticalAlign(`top),
      lineHeight(`rem(1.3)),
      borderTop(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
      borderBottom(`pt(1), `solid, `rgba((155, 155, 155, 0.3))),
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
