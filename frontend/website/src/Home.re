let extraHeaders = <link rel="stylesheet" type_="text/css" href="index.css" />;

let component = ReasonReact.statelessComponent("Home");
let make = _ => {
  ...component,
  render: _self => <section> <HeroSection /> </section>,
};
