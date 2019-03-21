open Style;

let str = ReasonReact.string;

let component = ReasonReact.statelessComponent("Career");
let make = _ => {
  ...component,
  render: _self => {
    <h3 className=H3.wings> {str("Run Coda")} </h3>;
  },
};
