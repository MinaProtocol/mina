open Tc;

module UnlockAccount = [%graphql
  {| mutation unlock($password: String, $publicKey: PublicKey) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

module UnlockMutation = ReasonApollo.CreateMutation(UnlockAccount);

type modalState = {error: option(string)};
[@react.component]
let make = (~account, ~onClose, ~onSuccess) => {
  let (error, setError) = React.useState(() => None);
  let (password, setPassword) = React.useState(() => "");
  let variables =
    UnlockAccount.make(
      ~password,
      ~publicKey=Apollo.Encoders.publicKey(account),
      (),
    )##variables;
  <Modal title="Unlock Account" onRequestClose=onClose>
    <UnlockMutation>
      ...{(mutation, {result}) =>
        <form
          className=Modal.Styles.default
          onSubmit={event => {
            ReactEvent.Form.preventDefault(event);
            mutation(
              ~variables,
              ~refetchQueries=[|"getWallets", "walletLocked"|],
              (),
            )
            |> ignore;
          }}>
          {switch (result) {
           | NotCalled
           | Loading => React.null
           | Data(_) =>
             onSuccess();
             React.null;
           | Error(err) =>
             let message =
               err##graphQLErrors
               |> Js.Nullable.toOption
               |> Option.withDefault(~default=Array.empty)
               |> Array.get(~index=0)
               |> Option.map(~f=e => e##message)
               |> Option.withDefault(~default="Server error");
             setError(_ => Some(message));
             React.null;
           }}
          <p className=Theme.Text.Body.regular>
            {React.string("Please enter password for ")}
            <AccountName pubkey=account />
            {React.string(".")}
          </p>
          <Spacer height=1. />
          <TextField
            label="Pass"
            type_="password"
            onChange={value => setPassword(_ => value)}
            value=password
            ?error
          />
          <Spacer height=1.5 />
          <div className=Css.(style([display(`flex)]))>
            <Button
              label="Cancel"
              style=Button.Gray
              onClick={_ => onClose()}
            />
            <Spacer width=1. />
            <Button label="Unlock" style=Button.Green type_="submit" />
          </div>
        </form>
      }
    </UnlockMutation>
  </Modal>;
};
