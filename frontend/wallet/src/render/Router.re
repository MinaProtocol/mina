module Styles = {
  open Css;

  let container = style([width(`percent(100.)), overflow(`scroll)]);
};

let navigate = route => ReasonReact.Router.push("#" ++ Route.print(route));

[@react.component]
let make = (~dispatch: CodaProcess.Action.t => unit) => {
  let url = ReasonReactRouter.useUrl();
  <div className=Styles.container>
    {switch (url.path) {
     | ["settings"] => <SettingsPage dispatch />
     | _ => <TransactionsView />
     }}
  </div>;
};
