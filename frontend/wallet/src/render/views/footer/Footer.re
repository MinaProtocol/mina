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
      padding2(~v=`zero, ~h=`rem(1.25)),
      borderTop(`px(1), `solid, Theme.Colors.borderColor),
    ]);

  let footerButtons = style([display(`flex)]);

  let stakingSwitch =
    style([
      color(Theme.Colors.serpentine),
      display(`flex),
      alignItems(`center),
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
      <Toggle value=staking onChange=setStaking />
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
        {ReasonReact.string("Compress the blockchain")}
      </span>
    </div>;
  };
};

type ownedWallets =
  Wallet.t = {
    publicKey: PublicKey.t,
    balance: {. "total": int64},
  };

module Wallets = [%graphql
  {| query getWallets { ownedWallets @bsRecord {
      publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      balance {
          total @bsDecoder(fn: "Apollo.Decoders.int64")
      }
    }} |}
];

module WalletQuery = ReasonApollo.CreateQuery(Wallets);

module SendPayment = [%graphql
  {|
    mutation (
      $from: PublicKey!,
      $to_: PublicKey!,
      $amount: UInt64!,
      $fee: UInt64!,
      $memo: String) {
      sendPayment(input:
                    {from: $from, to: $to_, amount: $amount, fee: $fee, memo: $memo}) {
        payment {
          nonce
        }
      }
    }
  |}
];

module SendPaymentMutation = ReasonApollo.CreateMutation(SendPayment);

[@react.component]
let make = () => {
  let (modalState, setModalState) = React.useState(() => false);
  <div className=Styles.footer>
    <StakingSwitch />
    <div className=Styles.footerButtons>
      <WalletQuery partialRefetch=true>
        {response =>
           switch (response.result) {
           | Loading
           | Error(_) => <Button label="Send" style=Button.Gray />
           | Data(data) =>
             <>
               <Button
                 label="Request"
                 style=Button.Gray
                 onClick={_ => setModalState(_ => true)}
               />
               {switch (modalState) {
                | false => React.null
                | true =>
                  <RequestCodaModal wallets=data##ownedWallets setModalState />
                }}
               <Spacer width=1. />
               <SendPaymentMutation>
                 (
                   (mutation, _) =>
                     <SendButton
                       wallets=data##ownedWallets
                       onSubmit={(
                         {from, to_, amount, fee, memoOpt}: SendButton.ModalState.Validated.t,
                         afterSubmit,
                       ) => {
                         let variables =
                           SendPayment.make(
                             ~from=Apollo.Encoders.publicKey(from),
                             ~to_=Apollo.Encoders.publicKey(to_),
                             ~amount=Js.Json.string(amount),
                             ~fee=Js.Json.string(fee),
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
                             | EmptyResponse => afterSubmit(Belt.Result.Ok())
                             | Errors(err) => {
                                 /* TODO: Display more than first error? */
                                 let message =
                                   err
                                   |> Array.get(~index=0)
                                   |> Option.map(~f=e => e##message)
                                   |> Option.withDefault(
                                        ~default="Server error",
                                      );
                                 afterSubmit(Error(message));
                               },
                         );
                       }}
                     />
                 )
               </SendPaymentMutation>
             </>
           }}
      </WalletQuery>
    </div>
  </div>;
};
