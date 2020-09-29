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
        unsafe("width", "max-content"),
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
          transitions([
            `transition("200ms ease-in 0ms transform"),
            `transition("50ms ease-in 100ms border"),
          ]),
        ]),
        color(
          {
            bgColor === Theme.Colors.white ? Theme.Colors.digitalBlack : white;
          },
        ),
        padding2(~v=`rem(paddingY), ~h=`rem(paddingX)),
        textAlign(`center),
        hover([
          color(white),
          after([
            border(`zero, `solid, `rgba(0, 0, 0, 0.)),
            transform(translate(`rem(-0.25), `rem(-0.25))),
          ]),
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

module Link = {
  [@react.component]
  let make = (~href, ~children) => {
    switch (href) {
    | `Scroll_to_top => <Next.Link href=""> children </Next.Link>
    | `External(href) => <a className=Css.(style([textDecoration(`none)])) href> children </a>
    | `Internal(href) =>
      <Next.Link href> children </Next.Link>
    }
  };
};

/**
 * Button is light by default, and setting dark to true as a prop will make the background image change accordingly.
 * Buttons have four different colors: orange, mint, black, and white.
 */
[@react.component]
let make =
    (
      ~href,
      ~children=?,
      ~height=`rem(3.25),
      ~width=`rem(10.9),
      ~borderColor=Theme.Colors.black,
      ~paddingX=1.5,
      ~paddingY=0.,
      ~bgColor=Theme.Colors.orange,
      ~dark=false,
      ~onClick=?,
    ) => {
  <Link href>
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
  </Link>;
};
