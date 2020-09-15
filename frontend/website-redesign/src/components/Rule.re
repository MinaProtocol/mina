module Styles = {
  open Css;
  let rule = ruleColor =>
    style([
      margin(`zero),
      width(`percent(100.)),
      border(`px(1), `solid, ruleColor),
    ]);
};

[@react.component]
let make = (~color as ruleColor=Theme.Colors.digitalBlack) => {
  <hr className={Styles.rule(ruleColor)} />;
};
