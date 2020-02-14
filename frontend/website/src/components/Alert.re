module Style = {
  open Css;

  let main = c =>
    style([
      border(px(1), `solid, c),
      borderRadius(px(9)),
      overflow(`hidden),
    ]);

  let inner =
    merge([style([margin(`zero), padding2(~v=`rem(0.), ~h=`rem(1.))])]);

  let title = c =>
    merge([
      Theme.Body.basic,
      style([
        textTransform(`capitalize),
        fontWeight(`num(600)),
        color(`hex("FFFFFF")),
        backgroundColor(c),
        margin(`zero),
        padding2(~v=`rem(0.5), ~h=`rem(1.)),
      ]),
    ]);
};

[@react.component]
let make = (~kind="", ~children) => {
  let (title, color) =
    switch (kind) {
    | "warning" => ("warning", Theme.Colors.rosebudAlpha(0.8))
    | "danger" => ("danger", Theme.Colors.rosebudAlpha(0.8))
    | "welcome" => ("welcome", Theme.Colors.tealBlueAlpha(0.8))
    | "status" => ("status", Theme.Colors.indiaAlpha(0.8))
    | _ => ("note", Theme.Colors.marineAlpha(0.8))
    };
  <div className={Style.main(color)}>
    <p className={Style.title(color)}> {React.string(title)} </p>
    <div className=Style.inner> children </div>
  </div>;
};

let default = make;
