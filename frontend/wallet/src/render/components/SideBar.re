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
};

module Wallets = [%graphql
  {| query { wallets {publicKey, balance {total}} } |}
];
module WalletQuery = ReasonApollo.CreateQuery(Wallets);

[@react.component]
let make = () => {
  let (addWalletModalOpen, setModalOpen) = React.useState(() => false);

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
    <button onClick={_ => setModalOpen(_ => true)}>
      {React.string("+ Add wallet")}
    </button>
    <Modal
      isOpen=addWalletModalOpen
      contentLabel="Add Wallet"
      onRequestClose={() => setModalOpen(_ => false)}>
      {React.string("Add wallet:")}
      <br />
      <input type_="text" value="test" />
      <br />
      <button onClick={_ => setModalOpen(_ => false)}>
        {React.string("Cancel")}
      </button>
    </Modal>
  </div>;
};
