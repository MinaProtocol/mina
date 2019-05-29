module Styles = {
  open Css;

  let container =
    style([
      height(`percent(100.)),
      padding(`rem(2.)),
      backgroundColor(Theme.Colors.greyish(0.1)),
    ]);
};

module SettingsQueryString = [%graphql {| query settings { version } |}];

module SettingsQuery = ReasonApollo.CreateQuery(SettingsQueryString);

[@react.component]
let make = () => {
  <div className=Styles.container>
    <span className=Theme.Text.title> {React.string("Settings")} </span>
    <Spacer height=1. />
    <SettingsQuery>
      {response =>
         switch (response.result) {
         | Loading => React.string("...")
         | Error(err) => React.string(err##message)
         | Data(data) =>
           <span className=Theme.Text.Body.regular>
             {React.string("Wallet version: " ++ data##version)}
           </span>
         }}
    </SettingsQuery>
  </div>;
};
