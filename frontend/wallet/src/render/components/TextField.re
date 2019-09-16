module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`flexStart),
      height(`rem(2.5)),
      width(`percent(100.)),
      padding2(~v=`zero, ~h=`rem(0.75)),
      background(white),
      border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
      borderRadius(`rem(0.25)),
      flexGrow(1.),
    ]);

  let label =
    merge([
      Theme.Text.Header.h6,
      style([
        textTransform(`uppercase),
        color(Theme.Colors.slateAlpha(0.7)),
        minWidth(`rem(2.5)),
      ]),
    ]);

  let placeholderColor = Theme.Colors.slateAlpha(0.5);

  let input =
    merge([
      Theme.Text.Body.regular,
      style([
        placeholder([color(placeholderColor)]),
        border(`zero, `none, transparent),
        flexGrow(1.),
        padding(`zero),
        paddingBottom(`px(2)),
        color(Theme.Colors.teal),
        active([outline(`zero, `solid, white)]),
        focus([outline(`zero, `solid, white)]),
      ]),
    ]);

  let inputMono =
    merge([
      Theme.Text.Body.mono,
      style([
        placeholder([color(placeholderColor)]),
        border(`zero, `none, transparent),
        flexGrow(1.),
        padding(`zero),
        color(Theme.Colors.teal),
        active([outline(`zero, `solid, white)]),
        focus([outline(`zero, `solid, white)]),
      ]),
    ]);

  let square = active =>
    style([
      marginRight(`rem(0.25)),
      paddingBottom(`px(2)),
      Theme.Typeface.lucidaGrande,
      color(active ? Theme.Colors.teal : placeholderColor),
    ]);

  let baseButton =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        justifyContent(`center),
        height(`rem(1.5)),
        minWidth(`rem(3.5)),
        padding2(~v=`zero, ~h=`rem(0.5)),
        border(`px(0), `none, transparent),
        borderRadius(`rem(0.25)),
        active([outlineStyle(`none)]),
        focus([outlineStyle(`none)]),
        disabled([pointerEvents(`none)]),
        marginRight(`rem(-0.25)),
        marginLeft(`rem(0.25)),
      ]),
    ]);

  let greenButton =
    merge([
      baseButton,
      style([
        backgroundColor(Theme.Colors.serpentine),
        color(white),
        hover([backgroundColor(Theme.Colors.jungle)]),
      ]),
    ]);

  let blueButton =
    merge([
      baseButton,
      style([
        backgroundColor(Theme.Colors.hyperlink),
        color(white),
        hover([backgroundColor(Theme.Colors.hyperlinkAlpha(0.7))]),
      ]),
    ]);

  let tealButton =
    merge([
      baseButton,
      style([
        backgroundColor(Theme.Colors.teal),
        color(white),
        hover([backgroundColor(Theme.Colors.tealAlpha(0.7))]),
      ]),
    ]);
};

module Button = {
  [@react.component]
  let make = (~text, ~color, ~disabled=false, ~onClick) => {
    let buttonStyle =
      switch (color) {
      | `Blue => Styles.blueButton
      | `Teal => Styles.tealButton
      | `Green => Styles.greenButton
      };
    <button className=buttonStyle disabled onClick={_ => onClick()}>
      {React.string(text)}
    </button>;
  };
};

module Currency = {
  [@react.component]
  let make = (~onChange, ~value, ~label, ~placeholder=?) =>
    <label className=Styles.container>
      <span className=Styles.label> {React.string(label ++ ":")} </span>
      <Spacer width=0.5 />
      <span className={Styles.square(value != "")}>
        {ReasonReact.string({j|■|j})}
      </span>
      <input
        className=Styles.input
        type_="number"
        onChange={e => {
          let value =
            ReactEvent.Form.target(e)##value
            |> Js.String.replaceByRe([%re "/[^0-9]/g"], "");
          onChange(value);
        }}
        value
        ?placeholder
      />
    </label>;
};

[@react.component]
let make =
    (
      ~onChange,
      ~value,
      ~label,
      ~mono=false,
      ~button=React.null,
      ~placeholder=?,
      ~disabled=false,
    ) =>
  <label className=Styles.container>
    <span className=Styles.label> {React.string(label ++ ":")} </span>
    <Spacer width=0.5 />
    <input
      className={mono ? Styles.inputMono : Styles.input}
      type_
      onChange={e => onChange(ReactEvent.Form.target(e)##value)}
      value
      ?placeholder
      disabled
    />
    button
  </label>;
