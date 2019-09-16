[@react.component]
let make = (~wallet, ~password, ~setModalState, ~onSubmit) => {
  <Modal title="Unlock Wallet" onRequestClose={() => setModalState(_ => None)}>
    <div className=Modal.Styles.default>
      <p className=Theme.Text.Body.regular>
        {React.string("Please enter password for ")}
        <WalletName pubkey=wallet />
        {React.string(".")}
      </p>
      <Spacer height=1. />
      <TextField
        label="Pass"
        type_="password"
        onChange={value => setModalState(_ => Some(value))}
        value=password
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
          label="Unlock"
          style=Button.Green
          onClick={_ => {
            onSubmit(password);
            setModalState(_ => None);
          }}
        />
      </div>
    </div>
  </Modal>;
};
