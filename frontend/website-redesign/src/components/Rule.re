module Styles = {
  open Css;
  let rule = ruleColor =>
    style([
      marginTop(`zero),
      marginBottom(`zero),
      marginLeft(`zero),
      marginRight(`zero),
      border(`px(1), `solid, ruleColor),
    ]);
};

[@react.component]
let make = (~color as ruleColor=Theme.Colors.digitalBlack) => {
  <hr className={Styles.rule(ruleColor)} />;
};
