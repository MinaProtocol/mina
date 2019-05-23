open Tc;

module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      width(`percent(100.)),
      height(`auto),
      overflowY(`auto),
      paddingBottom(`rem(2.)),
    ]);
};

[@react.component]
let make = (~wallets) =>
  <div className=Styles.container>
    {React.array(Array.map(~f=wallet => <WalletItem wallet />, wallets))}
  </div>;
