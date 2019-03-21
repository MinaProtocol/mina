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
      </Wrapped>
      <div className=Css.(style([backgroundColor(Style.Colors.gandalf)]))>
        <Wrapped> <TeamSection /> <InvestorsSection /> </Wrapped>
      </div>
    </section>,
};
