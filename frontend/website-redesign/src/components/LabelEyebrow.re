module Styles = {
  open Css;
  let link =
    style([
      Theme.Typeface.monumentGrotesk,
      cursor(`pointer),
      color(Theme.Colors.orange),
      display(`flex),
      marginTop(`rem(1.)),
    ]);

  let text =
    style([
      marginRight(`rem(0.2)),
      cursor(`pointer),
      marginBottom(`rem(2.)),
    ]);
};

[@react.component]
let make = (~copy) => {
  <h4 className=Theme.Type.h4>{React.string(copy)}</h4>
};
