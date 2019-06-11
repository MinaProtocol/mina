open Tc;

module Styles = {
  open Css;
    
  let currencySymbol = 
    style([Theme.Typeface.lucidaGrande]);
};

[@react.component]
let make = (
  ~label,
  ~value,
  ~onChange,
  ~wallets,
) =>
  <Dropdown
    label
    value
    onChange
    options={
      wallets
      |> Array.map(~f=wallet =>
          (
            PublicKey.toString(wallet.Wallet.key),
            /* TODO(PM): Fix styling here once we get design */
            <span>
              <WalletName pubkey={wallet.key} />
              {React.string(" ( ")}
              <span className=Styles.currencySymbol>
                {React.string({j|■|j})}
              </span>
              {React.string(" " ++ wallet.Wallet.balance ++ " )")}
            </span>,
          )
        )
      |> Array.toList
    }
  />;
