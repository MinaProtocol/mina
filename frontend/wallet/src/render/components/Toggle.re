module Styles = {
  open Css;

  let toggle =
    style([
      display(`inlineBlock),
      height(`rem(1.5)),
      position(`relative),
      width(`rem(2.5)),
      selector("input", [display(`none)]),
    ]);

  let slider =
    style([
      position(`absolute),
      backgroundColor(`hex("ccc")),
      bottom(`px(0)),
      left(`px(0)),
      right(`px(0)),
      top(`px(0)),
      transition(~duration=400, "all"),
      borderRadius(`px(12)),
      cursor(`pointer),
      before([
        position(`absolute),
        bottom(`px(4)),
        left(`px(4)),
        height(`rem(1.)),
        width(`rem(1.)),
        transition(~duration=400, "all"),
        backgroundColor(white),
        unsafe("content", "\"\""),
        borderRadius(`percent(50.)),
      ]),
    ]);

  let input =
    style([
      checked([
        selector(" + div", [backgroundColor(Theme.Colors.serpentine)]),
        selector(" + div:before", [transform(`translateX(`rem(1.)))]),
      ]),
    ]);
};

[@react.component]
let make = (~value, ~onChange) =>
  <label className=Styles.toggle>
    <input
      className=Styles.input
      type_="checkbox"
      id="checkbox"
      checked=value
      onClick={_e => onChange(toggle => !toggle)}
    />
    <div className=Styles.slider />
  </label>;
