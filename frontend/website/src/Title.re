// TODO: On mobile left align

let component = ReasonReact.statelessComponent("Title");
let make = (~fontColor, ~text, _children) => {
  ...component,
  render: _self =>
    <h1
      className=Css.(
        merge([
          Style.H1.hero,
          style([color(fontColor), textAlign(`center)]),
        ])
      )>
      {ReasonReact.string(text)}
    </h1>,
};
