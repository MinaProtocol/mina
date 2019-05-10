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
let make = () => {
  let (settingsOrError, setSettingsOrError) = Hooks.useSettings();
  switch (settingsOrError) {
  | Belt.Result.Error(_) =>
    <div>
      <p> {React.string("There was an error loading your wallets.")} </p>
    </div>
  | Belt.Result.Ok(settings) =>
    <div className=Styles.container>
      {SettingsRenderer.entries(settings)
       // TODO: Replace with actual wallets graphql info
       |> Array.map(~f=((key, _)) =>
            <WalletItem
              key={PublicKey.toString(key)}
              wallet={Wallet.key, balance: "100"}
              settings
              setSettingsOrError
            />
          )
       |> ReasonReact.array}
    </div>
  };
};
