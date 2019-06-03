let component = ReasonReact.statelessComponent("A");
let make =
    (~name, ~id=?, ~href=?, ~target=?, ~className=?, ~innerHtml=?, children) => {
  ...component,
  render: _self => {
    let dangerouslySetInnerHTML =
      Belt.Option.map(innerHtml, innerHtml => {"__html": innerHtml});
    <a name ?id ?href ?target ?className ?dangerouslySetInnerHTML>
      ...children
    </a>;
  },
};
