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
      Theme.Text.smallHeader,
      style([
        textTransform(`uppercase),
        color(Theme.Colors.slateAlpha(0.7)),
      ]),
    ]);

  let placeholderColor = Theme.Colors.slateAlpha(0.5);

  let input =
    merge([
      Theme.Text.Body.regular,
      style([
        placeholder([color(placeholderColor)]),
        border(`zero, `solid, white),
        flexGrow(1.),
        padding(`zero),
        paddingBottom(`px(2)),
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
        type_="text"
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
let make = (~onChange, ~value, ~label, ~placeholder=?) =>
  <label className=Styles.container>
    <span className=Styles.label> {React.string(label ++ ":")} </span>
    <Spacer width=0.5 />
    <input
      className=Styles.input
      type_="text"
      onChange={e => onChange(ReactEvent.Form.target(e)##value)}
      value
      ?placeholder
    />
  </label>;
