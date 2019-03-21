module Size = {
  // pixels (width, height)
  type t = (int, int);

  let remX = ((x, _)) => Js.Int.toFloat(x) /. 16.0;
  let remY = ((_, y)) => Js.Int.toFloat(y) /. 16.0;

  let pixelsX = fst;
  let pixelsY = snd;
};

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
