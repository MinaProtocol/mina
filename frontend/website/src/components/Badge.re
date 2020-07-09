module Styles = {
  open Css;
  let icon =
    style([
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      margin2(~v=`zero, ~h=`px(4)),
      position(`relative),
      top(`px(1)),
    ]);
};

[@react.component]
let make = (~icon) => {
  <div className=Styles.icon> icon </div>;
};
