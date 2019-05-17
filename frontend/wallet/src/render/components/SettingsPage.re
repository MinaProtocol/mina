module Styles = {
  open Css;

  let container =
    style([
      height(`percent(100.)),
      padding2(~v=`rem(2.), ~h=`rem(4.)),
      backgroundColor(Theme.Colors.greyish(0.1)),
    ]);
};

[@react.component]
let make = () =>
  <div className=Styles.container>
    <span className=Theme.Text.title> {React.string("Settings")} </span>
  </div>;
