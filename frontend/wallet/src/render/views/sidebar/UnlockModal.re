open Tc;

module UnlockWallet = [%graphql
  {| mutation unlock($password: String, $publicKey: PublicKey) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

module UnlockMutation = ReasonApollo.CreateMutation(UnlockWallet);

type modalState = {error: option(string)};

[@react.component]
let make = (~wallet, ~onClose) => {
  let (error, setError) = React.useState(() => None);
  let (password, setPassword) = React.useState(() => "");
  <Modal title="Unlock Wallet" onRequestClose=onClose>
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
      {switch (error) {
       | Some(error) => <Alert kind=`Danger message=error />
       | None => React.null
       }}
      <Spacer height=1.5 />
      <div className=Css.(style([display(`flex)]))>
        <Button label="Cancel" style=Button.Gray onClick={_ => onClose()} />
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
                   Task.liftPromise(() =>
                     mutation(
                       ~variables,
                       ~refetchQueries=[|"getWallets", "walletLocked"|],
                       (),
                     )
                   );
                 Task.perform(
                   performMutation,
                   ~f=
                     fun
                     | EmptyResponse => ()
                     | Data(_) => onClose()
                     | Errors(err) => {
                         let message =
                           err
                           |> Array.get(~index=0)
                           |> Option.map(~f=e => e##message)
                           |> Option.withDefault(~default="Server error");
                         setError(_ => Some(message));
                       },
                 );
               }}
             />}
        </UnlockMutation>
      </div>
    </div>
  </Modal>;
};
