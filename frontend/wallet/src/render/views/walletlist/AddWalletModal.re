module Styles = {
  open Css;

  let container =
    style([
      margin(`auto),
      width(`rem(22.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
    ]);
};

// TODO: Add validation that the wallet name isn't already in use

[@react.component]
let make = (~walletName, ~setModalState, ~onSubmit) => {
  <Modal title="Add Wallet" onRequestClose={() => setModalState(_ => None)}>
    <div className=Styles.container>
      <Alert
        kind=`Info
        message="You can change the name or delete the wallet later."
      />
      <Spacer height=1. />
      <TextField
        label="Name"
        onChange={value => setModalState(_ => Some(value))}
        value=walletName
      />
      <Spacer height=1.5 />
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
