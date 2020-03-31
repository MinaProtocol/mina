open Tc;

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

type modalState = {
  delegate: option(PublicKey.t),
  fee: feeSelection,
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

let defaultFee = "5";

[@react.component]
let make = (~publicKey) => {
  // Form state
  let (state, changeState) =
    React.useState(() => {delegate: None, fee: DefaultAmount});

  let feeSelectedValue =
    switch (state.fee) {
    | DefaultAmount => 0
    | Custom(_) => 1
    };

  let onChangeFee = value =>
    switch (value) {
    | 0 => changeState(prev => {delegate: prev.delegate, fee: DefaultAmount})
    | _ =>
      changeState(prev => {delegate: prev.delegate, fee: Custom(defaultFee)})
    };

  let goBack = () =>
    ReasonReact.Router.push("/settings/" ++ PublicKey.uriEncode(publicKey));

  // Mutation variables and handlers
  let variables =
    ChangeDelegation.make(
      ~from=Apollo.Encoders.publicKey(publicKey),
      ~to_=
        Apollo.Encoders.publicKey(
          Option.withDefault(
            ~default=PublicKey.ofStringExn(""),
            state.delegate,
          ),
        ),
      ~fee=
        Apollo.Encoders.currency(
          switch (state.fee) {
          | DefaultAmount => defaultFee
          | Custom(amount) => amount
          },
        ),
      (),
    )##variables;

  <ChangeDelegationMutation>
    {(mutate, {loading, result}) =>
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
         {switch (result) {
          | NotCalled
          | Loading => React.null
          | Error((err: ReasonApolloTypes.apolloError)) =>
            <Alert kind=`Danger defaultMessage={err.message} />
          | Data(_) =>
            goBack();
            React.null;
          }}
         <div className=Theme.Text.Header.h3>
           {React.string("Delegate Participation To")}
         </div>
         <Spacer height=1. />
         <div className=Styles.fields>
           <TextField
             label="Key"
             value={
               Option.map(~f=PublicKey.toString, state.delegate)
               |> Option.withDefault(~default="")
             }
             mono=true
             onChange={value =>
               changeState(_ =>
                 {
                   delegate: Some(PublicKey.ofStringExn(value)),
                   fee: state.fee,
                 }
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
                    changeState(_ =>
                      {delegate: state.delegate, fee: Custom(value)}
                    )
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
               mutate(
                 ~variables,
                 ~refetchQueries=[|"getAccountInfo", "queryDelegation"|],
                 (),
               )
               |> ignore
             }
           />
         </div>
       </div>}
  </ChangeDelegationMutation>;
};
