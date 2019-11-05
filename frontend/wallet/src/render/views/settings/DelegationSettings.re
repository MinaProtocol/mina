open Tc;

module Styles = {
  open Css;

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.midnight), marginBottom(`rem(0.25))]),
    ]);
};

type modalState = {
  delegate: option(PublicKey.t),
  fee: option(Int64.t),
};

[@react.component]
let make = (~publicKey) => {
  let (state, updateModal) =
    React.useState(() => {delegate: None, fee: Some(Int64.of_int(5))});
  <div>
    <div>
      <div className=Styles.label> {React.string("Delegate to")} </div>
      <TextField
        label="Key"
        value={
          Option.map(~f=PublicKey.toString, state.delegate)
          |> Option.withDefault(~default="")
        }
        mono=true
        onChange={value =>
          updateModal(_ =>
            {delegate: Some(PublicKey.ofStringExn(value)), fee: state.fee}
          )
        }
      />
    </div>
    <Spacer height=1. />
    <div>
      <div className=Styles.label> {React.string("Transaction fee")} </div>
      <TextField.Currency
        label="Fee"
        value={
          Option.map(~f=Int64.to_string, state.fee)
          |> Option.withDefault(~default="")
        }
        placeholder="0"
        onChange={value => {
          let serializedValue =
            switch (value) {
            | "" => None
            | nonEmpty => Some(Int64.of_string(nonEmpty))
            };
          updateModal(_ => {delegate: state.delegate, fee: serializedValue});
        }}
      />
    </div>
    <Spacer height=1.5 />
    <div className=Css.(style([display(`flex)]))>
      <Button
        label="Cancel"
        style=Button.Gray
        onClick={_ => ReasonReact.Router.push("/settings/" ++ PublicKey.uriEncode(publicKey))}
      />
      <Spacer width=1. />
      <Button label="Save" style=Button.Green />
    </div>
  </div>;
};
