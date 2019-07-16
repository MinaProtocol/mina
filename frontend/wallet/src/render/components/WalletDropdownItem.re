module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
    ]);

  let currencySymbol = style([Theme.Typeface.lucidaGrande]);
};

[@react.component]
let make = (~wallet) =>
  /* TODO(PM): Update styling here once we get mockup */
  <div className=Styles.container>
    <WalletName pubkey={wallet.Wallet.publicKey} />
    <span>
      {React.string(" ( ")}
      <span className=Styles.currencySymbol> {React.string({j|■|j})} </span>
      {React.string(
         " " ++ Int64.to_string(wallet.Wallet.balance##total) ++ " )",
       )}
    </span>
  </div>;
