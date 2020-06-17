module Styles = {
  open Css;
  let button = (bgColor, bgColorHover) =>
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(bgColor),
        borderRadius(`px(6)),
        textDecoration(`none),
        fontSize(`rem(1.)),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(bgColorHover)]),
        media(
          Theme.MediaQuery.tablet,
          [marginLeft(`rem(0.)), alignSelf(`flexStart)],
        ),
      ]),
    ]);
};

[@react.component]
let make =
    (
      ~link,
      ~label,
      ~bgColor=Theme.Colors.hyperlink,
      ~bgColorHover=Theme.Colors.hyperlinkAlpha(1.),
    ) => {
  <Next.Link href=link>
    <a className={Styles.button(bgColor, bgColorHover)}>
      {React.string(label)}
    </a>
  </Next.Link>;
};
