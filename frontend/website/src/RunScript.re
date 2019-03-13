let str = ReasonReact.string;

let component = ReasonReact.statelessComponent("RunScript");

let make = ([|code|]) => {
  ...component,
  render: _self => <script dangerouslySetInnerHTML={"__html": code} />,
};
