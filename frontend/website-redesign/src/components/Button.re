module Styles = {
  open Css;
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
      Theme.Type.buttonLabel,
      style([
        position(`relative),
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
        width(buttonWidth),
        height(buttonHeight),
        border(`px(1), `solid, borderColor),
        backgroundColor(bgColor),
        borderTopLeftRadius(`px(4)),
        borderBottomRightRadius(`px(4)),
        borderTopRightRadius(`px(1)),
        borderBottomLeftRadius(`px(1)),
        cursor(`pointer),
        textDecoration(`none),
        fontSize(`px(12)),
        transformStyle(`preserve3d),
        transition("background", ~duration=200, ~timingFunction=`easeIn),
        //transition("transform", ~duration=500, ~timingFunction=`easeIn),
        after([
          position(`absolute),
          contentRule(""),
          top(`rem(0.25)),
          left(`rem(0.25)),
          right(`rem(-0.25)),
          bottom(`rem(-0.25)),
          borderTopLeftRadius(`px(4)),
          borderBottomRightRadius(`px(4)),
          borderTopRightRadius(`px(1)),
          borderBottomLeftRadius(`px(1)),
          border(`px(1), `solid, dark ? bgColor : borderColor),
          transform(translateZ(`px(-1))),
          transition("transform", ~duration=200, ~timingFunction=`easeIn),
        ]),
        color(
          {
            bgColor === Theme.Colors.white ? Theme.Colors.digitalBlack : white;
          },
        ),
        padding2(~v=`rem(paddingY), ~h=`rem(paddingX)),
        textAlign(`center),
        alignSelf(`center),
        hover([
          color(white),
          after([transform(translate(`rem(-0.25), `rem(-0.25)))]),
          backgrounds([
            {
              dark
                ? `url("/static/ButtonHoverDark.png")
                : `url("/static/ButtonHoverLight.png");
            },
            black,
          ]),
        ]),
      ]),
    ]);
};

/**
 * Button is light by default, and setting dark to true as a prop will make the background image change accordingly.
 * Buttons have four different colors: orange, mint, black, and white.
 */
[@react.component]
let make =
    (
      ~href="",
      ~children=?,
      ~height=`rem(3.25),
      ~width=`rem(10.9),
      ~borderColor=Theme.Colors.black,
      ~paddingX=1.5,
      ~paddingY=1.,
      ~bgColor=Theme.Colors.orange,
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
