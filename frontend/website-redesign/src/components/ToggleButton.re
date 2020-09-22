module ButtonStyles = {
  open Css;

  let textStyles =
    merge([Theme.Type.buttonLabel, style([textTransform(`uppercase)])]);

  let hoverStyles =
    hover([
      backgroundColor(Theme.Colors.orange),
      color(Theme.Colors.white),
    ]);

  let button =
    merge([
      textStyles,
      style([
        hoverStyles,
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        width(`rem(13.5)),
        height(`rem(2.5)),
        textAlign(`center),
        backgroundColor(Theme.Colors.white),
        color(Theme.Colors.black),
        cursor(`pointer),
        hover([
          color(white),
          backgrounds([
            {
              `url("/static/ButtonHoverLight.png");
            },
            black,
          ]),
        ]),
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
