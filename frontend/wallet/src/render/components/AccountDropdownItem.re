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
let make = (~account) =>
  <div className=Styles.container>
    <AccountName pubkey={account.Account.publicKey} />
    <span>
      {React.string(" ( ")}
      <span className=Styles.currencySymbol> {React.string({j|■|j})} </span>
      {React.string(
         " "
         ++ CurrencyFormatter.toFormattedString(
              account.Account.balance##total,
            )
         ++ " )",
       )}
    </span>
  </div>;
