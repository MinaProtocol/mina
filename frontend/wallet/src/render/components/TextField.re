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

  let input =
    merge([
      Theme.Text.Body.regular,
      style([
        border(`zero, `solid, white),
        flexGrow(1.),
        padding(`zero),
        paddingBottom(`px(2)),
        color(Theme.Colors.teal),
        active([outline(`zero, `solid, white)]),
        focus([outline(`zero, `solid, white)]),
      ]),
    ]);

  let square =
    style([
      marginRight(`rem(0.25)),
      Theme.Typeface.lucidaGrande,
      color(Theme.Colors.teal),
    ]);
};

[@react.component]
let make = (~onChange, ~isCurrency=false, ~value, ~label, ~placeholder=?) =>
  <label className=Styles.container>
    <span className=Styles.label> {React.string(label ++ ":")} </span>
    <Spacer width=0.5 />
    {isCurrency
       ? <span className=Styles.square>
           {ReasonReact.string({j|■|j})}
         </span>
       : React.null}
    <input
      className=Styles.input
      min=0
      type_="text"
      onChange={e => {
        let value =
          if (isCurrency) {
            ReactEvent.Form.target(e)##value
            |> Js.String.replaceByRe([%re "/[^0-9]/g"], "");
          } else {
            ReactEvent.Form.target(e)##value;
          };
        onChange(value);
      }}
      value
      ?placeholder
    />
  </label>;
