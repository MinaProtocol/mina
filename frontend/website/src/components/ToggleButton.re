module ButtonStyles = {
  open Css;

  let textStyles =
    merge([Theme.H6.extraSmall, style([textTransform(`uppercase)])]);

  let hover =
    hover([
      backgroundColor(Theme.Colors.hyperlinkHover),
      color(Theme.Colors.white),
      textShadow(~y=`px(1), Theme.Colors.blackAlpha(0.25)),
    ]);

  let button =
    merge([
      textStyles,
      style([
        hover,
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        width(`rem(13.5)),
        height(`rem(2.5)),
        textAlign(`center),
        backgroundColor(Theme.Colors.gandalf),
        color(Theme.Colors.denimTwo),
        cursor(`pointer),
      ]),
    ]);

  let selectedButton =
    merge([
      button,
      style([
        boxShadow(~blur=`px(30), Theme.Colors.blackAlpha(0.1)),
        textShadow(~y=`px(1), Theme.Colors.blackAlpha(0.25)),
        backgroundColor(Theme.Colors.hyperlink),
        color(Theme.Colors.white),
      ]),
    ]);
};

[@react.component]
let make = (~currentToggle, ~onTogglePress, ~label) => {
  <div
    className={
      currentToggle == label
        ? ButtonStyles.selectedButton : ButtonStyles.button
    }
    onClick={_ => onTogglePress(label)}>
    {React.string(label)}
  </div>;
};
