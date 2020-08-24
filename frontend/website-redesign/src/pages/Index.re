module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);
};

[@react.component]
let make = () => {
  <Page title="Coda Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Styles.page>
      <h1 className=Theme.Type.h1jumbo>
        {React.string("This is the homepage")}
      </h1>
    </div>
  </Page>;
};
