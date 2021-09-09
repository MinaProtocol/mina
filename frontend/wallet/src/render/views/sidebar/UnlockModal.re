open ReactIntl;
open Tc;

module Styles = {
  open Css;

  let subtitle =
    merge([Theme.Text.Body.regular, style([textTransform(`capitalize)])]);
};

module UnlockAccount = [%graphql
  {| mutation unlock($password: String!, $publicKey: PublicKey!) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

module UnlockMutation = ReasonApollo.CreateMutation(UnlockAccount);

type modalState = {error: option(string)};
[@react.component]
let make = (~account, ~onClose, ~onSuccess) => {
  let intl = useIntl();

  let modalTitle =
    Intl.formatMessage(
      intl,
      {
        "id": "unlock-modal.unlock-account",
        "defaultMessage": "Unlock Account",
      },
    );

  let (error, setError) = React.useState(() => None);
  let (password, setPassword) = React.useState(() => "");
  let variables =
    UnlockAccount.make(
      ~password,
      ~publicKey=Apollo.Encoders.publicKey(account),
      (),
    )##variables;
  <Modal title=modalTitle onRequestClose=onClose>
    <UnlockMutation>
      ...{(mutation, {result}) =>
        <form
          className=Modal.Styles.default
          onSubmit={event => {
            ReactEvent.Synthetic.stopPropagation(event);
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
           | Error((err: ReasonApolloTypes.apolloError)) =>
             let message =
               err.graphQLErrors
               |> Js.Nullable.toOption
               |> Option.withDefault(~default=[||])
               |> Array.get(~index=0)
               |> Option.map(~f=(e: ReasonApolloTypes.graphqlError) =>
                    e.message
                  )
               |> Option.withDefault(~default="Server error");
             setError(_ => Some(message));
             React.null;
           }}
          <p className=Styles.subtitle>
            <FormattedMessage
              id="unlock-modal.please-enter-password"
              defaultMessage="Please enter password for"
            />
            {React.string(" ")}
            <AccountName pubkey=account />
            {React.string(". ")}
            {if (PublicKey.toString(account) == "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g") {
                <FormattedMessage
                   id="unlock-modal.please-enter-password-hack"
                   defaultMessage="Leave password blank for this account."
                />
            } else {
               React.null
            }}
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
              onClick={evt => {
                ReactEvent.Synthetic.stopPropagation(evt);
                onClose();
              }}
            />
            <Spacer width=1. />
            <Button
              disabled={result === Loading}
              label="Unlock"
              style=Button.Green
              type_="submit"
            />
          </div>
        </form>
      }
    </UnlockMutation>
  </Modal>;
};
