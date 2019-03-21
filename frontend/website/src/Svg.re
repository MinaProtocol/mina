module Size = {
  // rem (width, height)
  type t = (float, float);

  let remX = fst;
  let remY = snd;

  let pixelsX = ((x, _)) => x *. 16.0 |> Js.Math.ceil;
  let pixelsY = ((_, y)) => y *. 16.0 |> Js.Math.ceil;
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
