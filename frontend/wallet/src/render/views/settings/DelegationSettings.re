module Styles = {
  open Css;

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.midnight), marginBottom(`rem(0.5))]),
    ]);

  let backHeader = style([display(`flex), alignItems(`center)]);
  let breadcrumbText =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.hyperlink), marginBottom(`rem(2.3))]),
    ]);
  let fields = style([maxWidth(`rem(40.))]);
};

type feeSelection =
  | DefaultAmount
  | Custom(string);

type errorOutcome =
  | EmptyDelegateKey
  | InvalidGraphQLResponse(string);

type modalState = {
  delegate: string,
  fee: feeSelection,
  error: option(errorOutcome),
};

module ChangeDelegation = [%graphql
  {|
    mutation changeDelegation(
      $from: PublicKey!,
      $to_: PublicKey!,
      $fee: UInt64!
    ) {
      sendDelegation(input: {from: $from, to: $to_, fee: $fee}) {
        delegation {
          nonce
        }
      }
    }
  |}
];
module ChangeDelegationMutation =
  ReasonApollo.CreateMutation(ChangeDelegation);

let defaultFee = "0.1";

[@react.component]
let make = (~publicKey) => {
  // Form state
  let (state, changeState) =
    React.useState(() => {delegate: "", fee: DefaultAmount, error: None});

  let feeSelectedValue =
    switch (state.fee) {
    | DefaultAmount => 0
    | Custom(_) => 1
    };

  let onChangeFee = value =>
    switch (value) {
    | 0 => changeState(prev => {...prev, fee: DefaultAmount})
    | _ => changeState(prev => {...prev, fee: Custom(defaultFee)})
    };

  let goBack = () =>
    ReasonReact.Router.push("/settings/" ++ PublicKey.uriEncode(publicKey));

  // Mutation variables and handlers
  let variables =
    ChangeDelegation.make(
      ~from=Apollo.Encoders.publicKey(publicKey),
      ~to_=Apollo.Encoders.publicKey(PublicKey.ofStringExn(state.delegate)),
      ~fee=
        Apollo.Encoders.currency(
          switch (state.fee) {
          | DefaultAmount => defaultFee
          | Custom(amount) => amount
          },
        ),
      (),
    )##variables;

  <ChangeDelegationMutation
    onCompleted={_ => goBack()}
    onError={(err: ReasonApolloTypes.apolloError) =>
      changeState(prev =>
        {...prev, error: Some(InvalidGraphQLResponse(err.message))}
      )
    }>
    {(mutate, {loading}) =>
       <div className=SettingsPage.Styles.container>
         <div className=Styles.backHeader>
           <a
             className=Styles.breadcrumbText
             onClick={_ => ReasonReact.Router.push("/settings")}>
             {React.string("Global Settings >")}
           </a>
           <Spacer width=0.2 />
           <AccountName pubkey=publicKey className=Styles.breadcrumbText />
         </div>
         {switch (state.error) {
          | Some(EmptyDelegateKey) =>
            <Alert kind=`Danger defaultMessage="Please enter a public key" />
          | Some(InvalidGraphQLResponse(error)) =>
            <Alert kind=`Danger defaultMessage=error />
          | None => React.null
          }}
         <div className=Theme.Text.Header.h3>
           {React.string("Delegate Participation To")}
         </div>
         <Spacer height=1. />
         <div className=Styles.fields>
           <TextField
             label="Key"
             value={state.delegate}
             mono=true
             onChange={value =>
               changeState(_ =>
                 {delegate: value, fee: state.fee, error: None}
               )
             }
           />
         </div>
         <Spacer height=1. />
         <div>
           <div className=Styles.label>
             {React.string("Transaction fee")}
           </div>
           <div className=Styles.fields>
             <ToggleButton
               options=[|
                 "Standard: " ++ defaultFee ++ " Coda",
                 "Custom Amount",
               |]
               selected=feeSelectedValue
               onChange=onChangeFee
             />
           </div>
           {switch (state.fee) {
            | DefaultAmount => React.null
            | Custom(fee) =>
              <>
                <Spacer height=1. />
                <TextField.Currency
                  label="Fee"
                  value=fee
                  placeholder="0"
                  onChange={value => {
                    changeState(prev => {...prev, fee: Custom(value)})
                  }}
                />
              </>
            }}
         </div>
         <Spacer height=2. />
         <span
           className=Css.(
             merge([
               Theme.Text.Body.regular,
               style([color(Theme.Colors.slate)]),
             ])
           )>
           {React.string("Delegation will take effect in 24-36 hours.")}
         </span>
         <Spacer height=1. />
         <div className=Css.(style([display(`flex)]))>
           <Button label="Cancel" style=Button.Gray onClick={_ => goBack()} />
           <Spacer width=1. />
           <Button
             label="Delegate"
             style=Button.Green
             disabled=loading
             onClick={_ =>
               switch (state.delegate) {
               | "" =>
                 changeState(prev =>
                   {...prev, error: Some(EmptyDelegateKey)}
                 )
               | _ =>
                 mutate(
                   ~variables,
                   ~refetchQueries=[|"getAccountInfo", "queryDelegation"|],
                   (),
                 )
                 |> ignore
               }
             }
           />
         </div>
       </div>}
  </ChangeDelegationMutation>;
};