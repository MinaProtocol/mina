module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);
};

[@react.component]
let make = () => {
  <Page title="Coda Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Styles.page> <h1> {React.string("Homepage")} </h1> </div>
  </Page>;
};
