/*
   TODO: This file was copied from the website-redesign. It was copied over to use the styles
          that the new website uses. The components that use this component should be updated
          when they are ported over to the website-redesign.
 */

module Styles = {
  open Css;

  let buttonLabel =
    style([
      Theme.Typeface.monumentGrotesk,
      fontSize(`rem(0.75)),
      fontWeight(`num(500)),
      lineHeight(`rem(1.)),
      color(black),
      textTransform(`uppercase),
      letterSpacing(`px(1)),
    ]);

  let button =
      (
        bgColor,
        borderColor,
        dark,
        buttonHeight,
        buttonWidth,
        paddingX,
        paddingY,
      ) =>
    merge([
      buttonLabel,
      style([
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        width(buttonWidth),
        height(buttonHeight),
        border(`px(1), `solid, borderColor),
        boxShadow(~x=`px(4), ~y=`px(4), black),
        backgroundColor(bgColor),
        borderTopLeftRadius(`px(4)),
        borderBottomRightRadius(`px(4)),
        borderTopRightRadius(`px(1)),
        borderBottomLeftRadius(`px(1)),
        textDecoration(`none),
        fontSize(`px(12)),
        color(
          {
            bgColor === Theme.Colors.white ? black : white;
          },
        ),
        padding2(~v=`rem(paddingY), ~h=`rem(paddingX)),
        textAlign(`center),
        alignSelf(`center),
        hover([
          color(white),
          boxShadow(~x=`px(0), ~y=`px(0), black),
          unsafe(
            "transition",
            "box-shadow 0.2s ease-in, transform 0.5s ease-in",
          ),
          background(
            {
              dark
                ? `url("/static/img/ButtonHoverDark.png")
                : `url("/static/img/ButtonHoverLight.png");
            },
          ),
        ]),
      ]),
    ]);
};

/**
 * Button is light by default, and setting dark to true as a prop will make the background image change accordingly.
 * Buttons have four different colors: orange, mint, black, and white.
 *
 */
[@react.component]
let make =
    (
      ~href="",
      ~children=?,
      ~height=`rem(3.25),
      ~width=`rem(10.9),
      ~borderColor=Theme.Colors.minaBlack,
      ~paddingX=1.5,
      ~paddingY=1.,
      ~bgColor=Theme.Colors.minaOrange,
      ~dark=false,
      ~onClick=?,
    ) => {
  <Next.Link href>
    <button
      ?onClick
      className={Styles.button(
        bgColor,
        borderColor,
        dark,
        height,
        width,
        paddingX,
        paddingY,
      )}>
      {switch (children) {
       | Some(children) => children
       | None => React.null
       }}
    </button>
  </Next.Link>;
};
