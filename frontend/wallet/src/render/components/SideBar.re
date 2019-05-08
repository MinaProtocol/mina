module Styles = {
  open Css;

  let sidebar =
    style([
      width(`rem(12.)),
      borderRight(`px(1), `solid, Theme.Colors.borderColor),
    ]);
};

[@react.component]
let make = () =>
  <div className=Styles.sidebar>
    {React.string("Wallet list goes here")}
  </div>;
