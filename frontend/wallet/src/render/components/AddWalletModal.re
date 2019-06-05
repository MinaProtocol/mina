module Styles = {
  open Css;

  let container =
    style([
      margin(`auto),
      width(`rem(21.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
    ]);

  let alert = style([margin2(~v=`rem(1.), ~h=`zero)]);
};

// TODO: Add validation that the wallet name isn't already in use

[@react.component]
let make = (~walletName, ~setModalState, ~onSubmit) => {
  <Modal title="Add Wallet" onRequestClose={() => setModalState(_ => None)}>
    <div className=Styles.container>
      <Spacer height=1. />
      <TextField
        label="Name"
        onChange={value => setModalState(_ => Some(value))}
        value=walletName
      />
      <div className=Styles.alert>
        <Alert
          kind=`Info
          message="You can change or delete your wallet later."
        />
      </div>
      <div className=Css.(style([display(`flex)]))>
        <Button
          label="Cancel"
          style=Button.Gray
          onClick={_ => setModalState(_ => None)}
        />
        <Spacer width=2. />
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
