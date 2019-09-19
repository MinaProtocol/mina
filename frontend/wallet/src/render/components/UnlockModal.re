open Tc;

module UnlockWallet = [%graphql
  {| mutation unlock($password: String, $publicKey: PublicKey) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

module UnlockMutation = ReasonApollo.CreateMutation(UnlockWallet);

[@react.component]
let make = (~wallet, ~setModalState, ~onClose) => {
  let (password, setPassword) = React.useState(() => "");
  <Modal
    title="Unlock Wallet" onRequestClose={() => setModalState(_ => false)}>
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
          onClick={_ => setModalState(_ => false)}
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
                 let performMutation =
                   Task.liftPromise(() => mutation(~variables, ()));
                 Task.perform(
                   performMutation,
                   ~f=
                     fun
                     | Data(_) =>
                       log(`Info, "Unlock successful of %s", publicKey)
                     | Error(e) =>
                       log(
                         `Error,
                         "Unlock failed for %s, error: %s",
                         publicKey,
                         Js.String.make(e),
                       )
                     | NotFound =>
                       log(`Error, "Got 'NotFound' unlocking %s", publicKey),
                 );
                 onClose();
               }}
             />}
        </UnlockMutation>
      </div>
    </div>
  </Modal>;
};
