open Tc;

module Styles = {
  open Css;

  let bodyMargin = style([margin(`rem(1.0))]);
};

// TODO: Add validation that the wallet name isn't already in use

[@react.component]
let make = (~modalState, ~setModalState, ~onSubmit) => {
  <Modal
    isOpen={Option.isSome(modalState)}
    title="Add Wallet"
    onRequestClose={() => setModalState(_ => None)}>
    <div
      className=Css.(
        style([
          display(`flex),
          flexDirection(`column),
          alignItems(`center),
          justifyContent(`center),
        ])
      )>
      <div className=Styles.bodyMargin>
        {React.string("Name:")}
        <input
          type_="text"
          onChange={e => {
            let value = ReactEvent.Form.target(e)##value;
            setModalState(_ => Some(value));
          }}
          value={Option.withDefault(modalState, ~default="")}
        />
      </div>
      <div className=Css.(style([display(`flex)]))>
        <Button
          label="Cancel"
          style=Button.Gray
          onClick={_ => setModalState(_ => None)}
        />
        <Spacer width=1. />
        <Button
          label="Create"
          style=Button.Green
          onClick={_ => {
            onSubmit(Option.getExn(modalState));
            setModalState(_ => None);
          }}
        />
      </div>
    </div>
  </Modal>;
};
