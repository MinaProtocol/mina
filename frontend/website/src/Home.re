let extraHeaders = <link rel="stylesheet" type_="text/css" href="index.css" />;

let component = ReasonReact.statelessComponent("Home");
let make = _ => {
  ...component,
  render: _self =>
    // nudge this up one half unit on mobile
    <section
      className=Css.(
        style([
          marginTop(`rem(-0.8125)),
          media(Style.MediaQuery.full, [marginTop(`rem(-0.25))]),
        ])
      )>
      <Wrapped overflowHidden=true>
        <HeroSection />
        <CryptoAppsSection />
        <InclusiveSection />
        <SustainableSection />
        <GetInvolvedSection />
      </Wrapped>
      <div
        className=Css.(
          style([
            backgroundColor(Style.Colors.gandalf),
            marginTop(`rem(10.)),
          ])
        )>
        <Wrapped> <TeamSection /> <InvestorsSection /> </Wrapped>
      </div>
    </section>,
};
