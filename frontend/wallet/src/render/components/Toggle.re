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
      backgroundColor(Theme.Colors.slateAlpha(0.7)),
      bottom(`zero),
      left(`zero),
      right(`zero),
      top(`zero),
      transition(~duration=400, "background"),
      transition(~duration=100, "transform"),
      borderRadius(`px(12)),
      hover([transform(`scale((1.07, 1.05)))]),
      before([
        position(`absolute),
        bottom(`px(4)),
        left(`px(4)),
        height(`rem(1.)),
        width(`rem(1.)),
        transition(~duration=400, "all"),
        background(`url("bg-texture.png")),
        backgroundSize(`cover),
        contentRule("\"\""),
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

  let label = style([]);
};

[@react.component]
let make = (~value, ~onChange) =>
  <label className=Styles.toggle>
    <input
      className=Styles.input
      type_="checkbox"
      id="checkbox"
      checked=value
      onChange={_e => onChange(toggle => !toggle)}
    />
    <div className=Styles.slider />
  </label>;
