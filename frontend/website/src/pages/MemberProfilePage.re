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
let make = () => {
  <Page title="Member Profile">
    <Wrapped> <div className=Styles.page> <ProfileHero /> </div> </Wrapped>
  </Page>;
};