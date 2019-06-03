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

  let footerButtons =
    style([
      
    ]);

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
    <div className=Styles.stakingSwitch>
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
        {ReasonReact.string("Compress the blockchain")}
      </span>
    </div>;
  };
};

module Wallets = [%graphql
  {| query getWallets { ownedWallets {publicKey, balance{total}} } |}
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

[@react.component]
let make = () => {
  let (downloading, setDownloadState) = React.useState(() => false);
  let (modalState, setModalState) = React.useState(() => None);
  <div className=Styles.footer>
    <StakingSwitch />
    {if (downloading) {
       let downloadName = "keys-temporary_hack-testnet_postake.tar.bz2";
       <Downloader
         keyName=downloadName
         onFinish={_ => setDownloadState(_ => false)}
       />;
     } else {
       <Button
         label="Download keys"
         onClick={_ => setDownloadState(_ => true)}
       />;
     }}
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
            onClick={_ => setModalState(_ => Some("active wallet"))}
          />
          {switch (modalState) {
            | None => React.null
            | _ =>
              <RequestCodaModal
                wallets={Array.map(
                  ~f=Wallet.ofGraphqlExn,
                  data##ownedWallets,
                )}
                setModalState
              />
          }}
           <SendPaymentMutation>
             (
               (mutation, _) =>
                 <SendButton
                   wallets={Array.map(
                     ~f=Wallet.ofGraphqlExn,
                     data##ownedWallets,
                   )}
                   onSubmit={(
                     {from, to_, amount, fee, memoOpt}: SendButton.ModalState.Validated.t,
                     afterSubmit,
                   ) => {
                     let variables =
                       SendPayment.make(
                         ~from=PublicKey.toString(from),
                         ~to_=PublicKey.toString(to_),
                         ~amount,
                         ~fee,
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
                               |> Option.withDefault(~default="Server error");
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
  </div>;
};
