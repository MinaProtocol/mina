module Styles = {
  open Css;

  let main =
    style([
      border(px(1), `solid, Theme.Colors.digitalBlack),
      borderRadius(px(4)),
      overflow(`hidden),
    ]);

  let inner =
    merge([style([margin(`zero), padding2(~v=`rem(0.), ~h=`rem(1.))])]);

  let title = c =>
    merge([
      Theme.Type.whiteLabel,
      style([
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
    | "warning" => ("warning", Theme.Colors.error)
    | "danger" => ("danger", Theme.Colors.error)
    | "welcome" => ("welcome", Theme.Colors.purple)
    | "status" => ("status", Theme.Colors.status)
    | _ => ("note", Theme.Colors.purple)
    };
  <div className=Styles.main>
    <p className={Styles.title(color)}> {React.string(title)} </p>
    <div className=Styles.inner> children </div>
  </div>;
};

let default = make;
