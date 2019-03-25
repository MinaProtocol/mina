module Size = {
  // rem (width, height)
  type t = (float, float);

  let remX = fst;
  let remY = snd;

  let pixelsX = ((x, _)) => x *. 16.0 |> Js.Math.ceil;
  let pixelsY = ((_, y)) => y *. 16.0 |> Js.Math.ceil;
};

let component = ReasonReact.statelessComponent("Svg");
let make = (~link, ~dims, ~inline=false, ~className="", _children) => {
  ...component,
  render: _self =>
    if (inline) {
      // Load the CSS inline so that we can get the fonts from the main page.
      let content =
        Node.Fs.readFileAsUtf8Sync(
          String.sub(link, 1, String.length(link) - 1),
        );
      <div dangerouslySetInnerHTML={"__html": content} />;
    } else {
      <svg
        version="1.1"
        baseProfile="full"
        xmlns="http://www.w3.org/2000/svg"
        className=Css.(
          merge([
            className,
            style([
              width(`rem(Size.remX(dims))),
              height(`rem(Size.remY(dims))),
            ]),
          ])
        )>
        <image
          xlinkHref=link
          width={Js.Float.toString(Size.remX(dims)) ++ "rem"}
          height={Js.Float.toString(Size.remY(dims)) ++ "rem"}
        />
      </svg>;
    },
};
