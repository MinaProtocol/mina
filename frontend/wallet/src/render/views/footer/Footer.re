open ReactIntl;

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
    let (staking, setStaking) = React.useState(() => false);
    <div
      className=Css.(
        style([
          color(Theme.Colors.serpentine),
          display(`flex),
          alignItems(`center),
          // Disable the switch until it's functional
          opacity(0.5),
          pointerEvents(`none),
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
              firstLetter([textTransform(`capitalize)]),
            ]),
          ])
        )>
        <FormattedMessage
          id="footer.compress-blockchain"
          defaultMessage="Compress the blockchain"
        />
      </span>
    </div>;
  };
};

type ownedAccounts =
  Account.t = {
    locked: option(bool),
    publicKey: PublicKey.t,
    balance: {. "total": int64},
  };

module Accounts = [%graphql
  {| query getWallets { ownedWallets @bsRecord {
      publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      locked
      balance {
          total @bsDecoder(fn: "Apollo.Decoders.int64")
      }
    }} |}
];

module AccountQuery = ReasonApollo.CreateQuery(Accounts);

[@react.component]
let make = () => {
  let (modalState, setModalState) = React.useState(() => false);
  <div className=Styles.footer>
    <StakingSwitch />
    <div className=Styles.footerButtons>
      <AccountQuery partialRefetch=true>
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
                  <RequestCodaModal
                    accounts=data##ownedWallets
                    setModalState
                  />
                }}
               <Spacer width=1. />
               <SendButton />
             </>
           }}
      </AccountQuery>
    </div>
  </div>;
};
