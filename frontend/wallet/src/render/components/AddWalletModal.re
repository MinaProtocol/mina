module Styles = {
  open Css;

  let bodyMargin = style([margin(`rem(1.0))]);
};

// TODO: Add validation that the wallet name isn't already in use

[@react.component]
let make = (~walletName, ~setModalState, ~onSubmit) => {
  <Modal
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
        <TextField
          label="Name"
          onChange={value => {
            setModalState(_ => Some(value));
          }}
          value=walletName
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
            onSubmit(walletName);
            setModalState(_ => None);
          }}
        />
      </div>
    </div>
  </Modal>;
};
