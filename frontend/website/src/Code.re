open Style;

let str = ReasonReact.string;

let extraHeaders =
  <>
    <link rel="stylesheet" type_="text/css" href="code.css" />
    <link
      rel="stylesheet"
      type_="text/css"
      href="https://use.typekit.net/mta7mwm.css"
    />
  </>;

let component = ReasonReact.statelessComponent("Career");
let make = _ => {
  ...component,
  render: _self => {
    <h3 className=H3.wings> {str("Run Coda")} </h3>;
  },
};
