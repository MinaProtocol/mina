open Tc;

module Styles = {
  open Css;

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.midnight), marginBottom(`rem(0.5))]),
    ]);

  let fields = style([maxWidth(`rem(40.))]);
};

type feeSelection =
  | DefaultAmount
  | Custom(Int64.t);

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

module EnableStaking = [%graphql
  {|
    mutation changeDelegation(
      $publicKey: PublicKey!
    ) {
      setStaking(input: {publicKeys: [$publicKey]}) {
        lastStaking
      }
    }
  |}
];
module EnableStakingMutation = ReasonApollo.CreateMutation(EnableStaking);

type delegateResponse = {publicKey: PublicKey.t};
type accountResponse = {
  stakingActive: bool,
  delegateAccount: option(delegateResponse),
};

module AccountInfo = [%graphql
  {|
    query stakingAccountInfo($publicKey: PublicKey!) {
      account(publicKey: $publicKey) @bsRecord {
        stakingActive
        delegateAccount @bsRecord {
          publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
        }
      }
    }
|}
];
module AccountInfoQuery = ReasonApollo.CreateQuery(AccountInfo);

[@react.component]
let make = (~publicKey, ~stakingActive=false) => {
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
      changeState(prev =>
        {delegate: prev.delegate, fee: Custom(Int64.of_int(5))}
      )
    };

  let goBack = () =>
    ReasonReact.Router.push("/settings/" ++ PublicKey.uriEncode(publicKey));

  // Mutation variables and handlers
  let variables =
    EnableStaking.make(~publicKey=Apollo.Encoders.publicKey(publicKey), ())##variables;

  let _changeVariables =
    ChangeDelegation.make(
      ~from=Apollo.Encoders.publicKey(publicKey),
      ~to_=Apollo.Encoders.publicKey(publicKey),
      ~fee=
        Apollo.Encoders.int64(
          switch (state.fee) {
          | DefaultAmount => Int64.of_int(5)
          | Custom(amount) => amount
          },
        ),
      (),
    )##variables;

  let queryVariables =
    AccountInfo.make(~publicKey=Apollo.Encoders.publicKey(publicKey), ())##variables;

  <AccountInfoQuery variables=queryVariables>
    ...{({result}) =>
      switch (result) {
      | Loading => <Loader />
      | Error(err) =>
        <Alert
          kind=`Danger
          defaultMessage={
            err##message;
          }
        />
      | Data(accountInfo) =>
        <EnableStakingMutation>
          (
            (mutate, {loading, result}) =>
              <div className=SettingsPage.Styles.container>
                {switch (result) {
                 | NotCalled
                 | Loading => React.null
                 | Error(err) =>
                   <Alert kind=`Danger defaultMessage=err##message />
                 | Data(_) =>
                   goBack();
                   React.null;
                 }}
                <h3 className=Theme.Text.Header.h3>
                  {React.string("Enable Staking")}
                </h3>
                <Spacer height=1. />
                <span className=Theme.Text.Body.regularLight>
                  {React.string(
                     "To recieve your staking reward, your computer must be on and running this application 100% of the time.",
                   )}
                </span>
                <Spacer height=1. />
                {accountInfo##account
                 |> Option.andThen(~f=account => account.delegateAccount)
                 |> Option.map(~f=delegate => delegate.publicKey == publicKey)
                 |> Option.withDefault(~default=false)
                   ? React.null
                   : <div>
                       <div className=Styles.label>
                         {React.string("Transaction fee")}
                       </div>
                       <div className=Styles.fields>
                         <ToggleButton
                           options=[|"Standard: 5 Coda", "Custom Amount"|]
                           selected=feeSelectedValue
                           onChange=onChangeFee
                         />
                         {switch (state.fee) {
                          | DefaultAmount => React.null
                          | Custom(feeAmount) =>
                            <>
                              <Spacer height=1. />
                              <TextField.Currency
                                label="Fee"
                                value={
                                  feeAmount == Int64.zero
                                    ? "" : Int64.to_string(feeAmount)
                                }
                                placeholder="0"
                                onChange={value => {
                                  let serializedValue =
                                    switch (value) {
                                    | "" => Int64.zero
                                    | nonEmpty => Int64.of_string(nonEmpty)
                                    };
                                  changeState(_ =>
                                    {
                                      delegate: state.delegate,
                                      fee: Custom(serializedValue),
                                    }
                                  );
                                }}
                              />
                            </>
                          }}
                       </div>
                       <Spacer height=1. />
                       <span
                         className=Css.(
                           merge([
                             Theme.Text.Body.regular,
                             style([color(Theme.Colors.slate)]),
                           ])
                         )>
                         {React.string(
                            "Staking will take effect in 24-36 hours.",
                          )}
                       </span>
                       <Spacer height=2. />
                     </div>}
                <div className=Css.(style([display(`flex)]))>
                  <Button
                    label="Cancel"
                    style=Button.Gray
                    onClick={_ => goBack()}
                  />
                  <Spacer width=1. />
                  <Button
                    label="Enable Staking"
                    style=Button.Green
                    disabled=loading
                    onClick={_ =>
                      mutate(
                        ~variables,
                        ~refetchQueries=[|"getAccountInfo"|],
                        (),
                      )
                      |> ignore
                    }
                  />
                </div>
              </div>
          )
        </EnableStakingMutation>
      }
    }
  </AccountInfoQuery>;
};