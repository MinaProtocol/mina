module Styles = {
  open Css;
  let icon =
    style([
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      marginLeft(`rem(0.5)),
      marginRight(`rem(0.5)),
      position(`relative),
      top(`px(1)),
    ]);
};

[@react.component]
let make = (~icon) => {
  <span className=Styles.icon> icon </span>;
};
