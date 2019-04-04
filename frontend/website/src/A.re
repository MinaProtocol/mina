let component = ReasonReact.statelessComponent("A");
let make = (~name, ~id=?, ~href=?, ~target=?, ~className=?, children) => {
  ...component,
  render: _self => {
    <a name ?id ?href ?target ?className> ...children </a>;
  },
};
