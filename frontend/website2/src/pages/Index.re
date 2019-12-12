module Styles = {
  open Css;
  let page =
    style([
      display(`block),
      justifyContent(`center),
      // margin(`auto),
      paddingLeft(`rem(3.)),
      paddingRight(`rem(3.)),
      marginTop(`rem(4.)),
    ]);
};

[@react.component]
let make = () => {
  <Page>
    <div className=Styles.page>
      <HeroSection />
      <CryptoAppsSection />
      <InclusiveSection />
      <SustainableSection />
      <GetInvolvedSection />
    </div>
  </Page>;
};
