module ButtonStyles = {
  open Css;

  let textStyles =
    merge([Theme.Type.h6, style([textTransform(`uppercase)])]);

  let hover =
    hover([
      backgroundColor(Theme.Colors.orange),
      color(Theme.Colors.white),
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
        backgroundColor(Theme.Colors.white),
        color(Theme.Colors.black),
        cursor(`pointer),
      ]),
    ]);

  let selectedButton =
    merge([
      button,
      style([
        backgroundColor(Theme.Colors.orange),
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
