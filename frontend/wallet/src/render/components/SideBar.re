open Tc;

module Styles = {
  open Css;

  let sidebar =
    style([
      width(`rem(12.)),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      borderRight(`px(1), `solid, Theme.Colors.borderColor),
    ]);

  let footer = style([padding2(~v=`rem(0.5), ~h=`rem(1.))]);
};

module Wallets = [%graphql
  {| query { wallets {publicKey, balance {total}} } |}
];
module WalletQuery = ReasonApollo.CreateQuery(Wallets);

[@react.component]
let make = () => {
  let (modalState, setModalState) = React.useState(() => None);

  <div className=Styles.sidebar>
    <WalletQuery>
      {response =>
         switch (response.result) {
         | Loading => React.string("...")
         | Error(err) => React.string(err##message)
         | Data(data) =>
           <WalletList
             wallets={Array.map(~f=Wallet.ofGraphqlExn, data##wallets)}
           />
         }}
    </WalletQuery>
    <div className=Styles.footer>
      <Link onClick={_ => setModalState(_ => Some("My Wallet"))}>
        {React.string("+ Add wallet")}
      </Link>
    </div>
    <AddWalletModal modalState setModalState />
  </div>;
};
