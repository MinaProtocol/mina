open Tc;

module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      width(`percent(100.)),
      height(`auto),
      overflowY(`auto),
      paddingBottom(`rem(2.)),
    ]);
};

module Wallets = [%graphql
  {| query getWallets { ownedWallets {publicKey, balance{total}}} |}
];
module WalletQuery = ReasonApollo.CreateQuery(Wallets);

[@react.component]
let make = () =>
  <WalletQuery partialRefetch=true>
    {response =>
       switch (response.result) {
       | Loading => <Loader.Page> <Loader /> </Loader.Page>
       | Error(err) => React.string(err##message)
       | Data(wallets) =>
         <div className=Styles.container>
           {React.array(
              Array.map(
                ~f=
                  wallet =>
                    <WalletItem
                      key={PublicKey.toString(wallet.key)}
                      wallet
                    />,
                Array.map(wallets##ownedWallets, ~f=Wallet.ofGraphqlExn),
              ),
            )}
         </div>
       }}
  </WalletQuery>;
