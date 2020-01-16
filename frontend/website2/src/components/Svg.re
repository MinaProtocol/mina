module Size = {
  // rem (width, height)
  type t = (float, float);

  let remX = fst;
  let remY = snd;

  let pixelsX = ((x, _)) => x *. 16.0 |> Js.Math.ceil;
  let pixelsY = ((_, y)) => y *. 16.0 |> Js.Math.ceil;
};

[@react.component]
let make = (~link, ~dims, ~inline=false, ~className=?, ~alt) => {
  <object
    data=link
    type_="image/svg+xml"
    width={Js.Int.toString(Size.pixelsX(dims))}
    height={Js.Int.toString(Size.pixelsY(dims))}
    role={String.length(alt) == 0 ? "presentation" : "img"}
    ariaHidden={String.length(alt) == 0}
    alt
    ariaLabel=alt
    className={
      switch (className) {
      | None =>
        Css.(
          style([
            width(`rem(Size.remX(dims))),
            height(`rem(Size.remY(dims))),
          ])
        )
      | Some(className) => className
      }
    }
  />;
};
