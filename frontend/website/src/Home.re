[@react.component]
let make = (~posts) => {
  // nudge this up one half unit on mobile
  <section
    className=Css.(
      style([
        marginTop(`rem(-0.3125)),
        media(Style.MediaQuery.full, [marginTop(`rem(-0.25))]),
      ])
    )>
    <Wrapped overflowHidden=true>
      <HeroSection />
      <CryptoAppsSection />
      <InclusiveSection />
      <SustainableSection />
      <GetInvolvedSection posts />
    </Wrapped>
    <div
      className=Css.(
        style([
          backgroundColor(Style.Colors.navyBlue),
          marginTop(`rem(13.)),
        ])
      )>
      <Wrapped> <TeamSection /> <InvestorsSection /> </Wrapped>
    </div>
  </section>;
};
