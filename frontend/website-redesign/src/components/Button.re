module Styles = {
  open Css;
  let button = (bgColor, dark, buttonHeight, buttonWidth) =>
    merge([
      Theme.Type.buttonLabel,
      style([
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
        width(buttonWidth),
        height(buttonHeight),
        border(`px(1), `solid, black),
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
        padding2(~v=`rem(1.), ~h=`rem(1.5)),
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
                ? `url("/static/ButtonHoverDark.png")
                : `url("/static/ButtonHoverLight.png");
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
      ~children,
      ~height=`rem(3.25),
      ~width=`rem(10.9),
      ~bgColor=Theme.Colors.orange,
      ~dark=false,
    ) => {
  <Next.Link href>
    <button className={Styles.button(bgColor, dark, height, width)}>
      children
    </button>
  </Next.Link>;
};
