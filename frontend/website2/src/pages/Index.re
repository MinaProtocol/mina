module Styles = {
  open Css;
  let page = style([display(`block), justifyContent(`center)]);
};

[@react.component]
let make = () => {
  <Page footerColor=Theme.Colors.navyBlue>
    <div className=Styles.page>
      <section
        className=Css.(
          style([
            marginTop(`rem(-0.3125)),
            media(Theme.MediaQuery.full, [marginTop(`rem(-0.25))]),
          ])
        )>
        <Wrapped>
          <HeroSection />
          <CryptoAppsSection />
          <InclusiveSection />
          <SustainableSection />
          <GetInvolvedSection />
        </Wrapped>
        <div
          className=Css.(
            style([
              backgroundColor(Theme.Colors.navyBlue),
              marginTop(`rem(13.)),
            ])
          )>
          <Wrapped> <TeamSection /> <InvestorsSection /> </Wrapped>
        </div>
      </section>
    </div>
  </Page>;
};
