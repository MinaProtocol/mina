module UnlockWallet = [%graphql
  {| mutation unlock($password: String, $publicKey: PublicKey) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

module UnlockMutation = ReasonApollo.CreateMutation(UnlockWallet);

[@react.component]
let make = (~wallet, ~onClose) => {
  let (password, setPassword) = React.useState(() => "");
  <Modal
    title="Unlock Wallet" onRequestClose=onClose>
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
        onChange={value => setPassword(_ => value)}
        value=password
      />
      <Spacer height=1.5 />
      <div className=Css.(style([display(`flex)]))>
        <Button
          label="Cancel"
          style=Button.Gray
          onClick={ _ => onClose()}
        />
        <Spacer width=1. />
        <UnlockMutation>
          {(mutation, _) =>
             <Button
               label="Unlock"
               style=Button.Green
               onClick={_ => {
                 let variables =
                   UnlockWallet.make(
                     ~password,
                     ~publicKey=Apollo.Encoders.publicKey(wallet),
                     (),
                   )##variables;
                 mutation(~variables, ()) |> ignore;
                 onClose();
               }}
             />}
        </UnlockMutation>
      </div>
    </div>
  </Modal>;
};
