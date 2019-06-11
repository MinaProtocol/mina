open Tc;

module Styles = {
  open Css;
    
  let container =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
    ]);

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
            /* TODO(PM): Update styling here once we get mockup */
            <div className=Styles.container>
              <WalletName pubkey={wallet.key} />
              <span>
                {React.string(" ( ")}
                <span className=Styles.currencySymbol>
                  {React.string({j|■|j})}
                </span>
                {React.string(" " ++ wallet.Wallet.balance ++ " )")}
              </span>
            </div>,
          )
        )
      |> Array.toList
    }
  />;
