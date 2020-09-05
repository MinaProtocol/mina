module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);

  let background =
    style([
      width(`percent(100.)),
      height(`rem(180.)),
      backgroundColor(Css_Colors.black),
      backgroundSize(`cover),
      backgroundImage(`url("/static/img/spectrum_primary.png")),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Testworld" footerColor=Theme.Colors.navyBlue>
    <div className=Styles.page>
      <div className=Styles.background>
        {React.string("This is test world")}
      </div>
    </div>
  </Page>;
};
