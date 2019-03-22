let extraHeaders = <link rel="stylesheet" type_="text/css" href="index.css" />;

let component = ReasonReact.statelessComponent("Home");
let make = _ => {
  ...component,
  render: _self =>
    <section>
      <Wrapped>
        <HeroSection />
        <CryptoAppsSection />
        <InclusiveSection />
        <SustainableSection />
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
