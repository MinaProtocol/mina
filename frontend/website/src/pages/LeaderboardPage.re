module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(58.0)),
      margin(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(89.))]),
    ]);
};

[@react.component]
let make = (~lastManualUpdatedDate) => {
  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page> <Summary lastManualUpdatedDate /> </div>
    </Wrapped>
  </Page>;
};