module Styles = {
  open Css;

  let container = style([width(`percent(100.)), overflow(`scroll)]);
};

[@react.component]
let make = () => {
  let url = ReasonReactRouter.useUrl();
  <div className=Styles.container>
    {switch (url.path) {
     | ["settings"] => <SettingsPage />
     | ["settings", publicKey] =>
       <WalletSettings publicKey={PublicKey.uriDecode(publicKey)} />
     | _ => <Transactions />
     }}
  </div>;
};
