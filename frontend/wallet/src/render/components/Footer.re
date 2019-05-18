open Tc;

module Styles = {
  open Css;

  let footer =
    style([
      position(`fixed),
      bottom(`zero),
      left(`zero),
      right(`zero),
      display(`flex),
      height(Theme.Spacing.footerHeight),
      justifyContent(`spaceBetween),
      alignItems(`center),
      padding2(~v=`zero, ~h=`rem(2.)),
      borderTop(`px(1), `solid, Theme.Colors.borderColor),
    ]);
};

module StakingSwitch = {
  [@react.component]
  let make = () => {
    let (staking, setStaking) = React.useState(() => true);
    <div
      className=Css.(
        style([
          color(Theme.Colors.serpentine),
          display(`flex),
          alignItems(`center),
        ])
      )>
      <Toggle value=staking onChange={_e => setStaking(staking => !staking)} />
      <span
        className=Css.(
          merge([
            Theme.Text.Body.regular,
            style([
              color(
                staking
                  ? Theme.Colors.serpentine : Theme.Colors.slateAlpha(0.7),
              ),
              marginLeft(`rem(1.)),
            ]),
          ])
        )>
        {ReasonReact.string("Earn Coda > Vault")}
      </span>
    </div>;
  };
};

module Wallets = [%graphql
  {| query getWallets { wallets {publicKey, balance {total}} } |}
];

module WalletQuery = ReasonApollo.CreateQuery(Wallets);

module SendPayment = [%graphql
  {|
  mutation sendPayment(
    $from: String!,
    $to_: String!,
    $amount: String!,
    $fee: String!,
    $memo: String) {
  createPayment(input:
                {from: $from, to: $to_, amount: $amount, fee: $fee, memo: $memo}) {
    payment {
      nonce
    }
  }
}
|}
];

module SendPaymentMutation = ReasonApollo.CreateMutation(SendPayment);

let validateInt64 = s =>
  switch (Int64.of_string(s)) {
  | i => i > Int64.zero
  | exception (Failure(_)) => false
  };

[@react.component]
let make = () => {
  <div className=Styles.footer>
    <StakingSwitch />
    <WalletQuery>
      {response =>
         switch (response.result) {
         | Loading
         | Error(_) => <Button label="Send" style=Button.Gray />
         | Data(data) =>
           <SendPaymentMutation>
             (
               (mutation, _) =>
                 <SendButton
                   wallets={Array.map(~f=Wallet.ofGraphqlExn, data##wallets)}
                   onSubmit={(
                     {SendButton.fromStr, toStr, amountStr, feeStr, memoOpt},
                     afterSubmit,
                   ) =>
                     switch (fromStr) {
                     | None =>
                       afterSubmit(
                         Some("Please specify a wallet to send from."),
                       )
                     | _ when toStr == "" =>
                       afterSubmit(
                         Some("Please specify a destination address."),
                       )
                     | _ when !validateInt64(amountStr) =>
                       afterSubmit(Some("Please specify a non-zero amount."))
                     | _ when !validateInt64(feeStr) =>
                       afterSubmit(Some("Please specify a non-zero fee."))
                     | Some(fromStr) =>
                       let variables =
                         SendPayment.make(
                           ~from=PublicKey.toString(fromStr),
                           ~to_=toStr,
                           ~amount=amountStr,
                           ~fee=feeStr,
                           ~memo=?memoOpt,
                           (),
                         )##variables;
                       let performMutation =
                         Task.liftPromise(() => mutation(~variables, ()));
                       Task.perform(
                         performMutation,
                         ~f=
                           fun
                           | Data(_)
                           | EmptyResponse => afterSubmit(None)
                           | Errors(err) => {
                               /* TODO: Display more than first error? */
                               let message =
                                 err
                                 |> Array.get(~index=0)
                                 |> Option.map(~f=e => e##message)
                                 |> Option.withDefault(
                                      ~default="Server error",
                                    );
                               afterSubmit(Some(message));
                             },
                       );
                     }
                   }
                 />
             )
           </SendPaymentMutation>
         }}
    </WalletQuery>
  </div>;
};
