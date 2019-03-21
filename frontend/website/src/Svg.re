let component = ReasonReact.statelessComponent("Svg");
let make = (~link, ~dims, _children) => {
  ...component,
  render: _self =>
    <svg
      className=Css.(
        style([
          width(`rem(Size.remX(dims))),
          height(`rem(Size.remY(dims))),
        ])
      )>
      <image
        xlinkHref=link
        width={Js.Int.toString(Size.pixelsX(dims))}
        height={Js.Int.toString(Size.pixelsY(dims))}
      />
    </svg>,
};
