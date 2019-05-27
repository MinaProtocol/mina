open Tc;

module Styles = {
  open Css;

  let container =
    style([
      height(`percent(100.)),
      padding2(~v=`rem(2.), ~h=`rem(4.)),
      backgroundColor(Theme.Colors.greyish(0.1)),
    ]);
};

[@react.component]
let make = (~dispatch) => {
  let (addressbook, _updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  <div className=Styles.container>
    <span className=Theme.Text.title> {React.string("Settings")} </span>
    <SideBar.WalletQuery>
      {response =>
         switch (response.result) {
         | Loading => React.string("...")
         | Error(err) => React.string(err##message)
         | Data(data) =>
           let wallets =
             Array.map(~f=Wallet.ofGraphqlExn, data##ownedWallets)
             |> Array.to_list;
           switch (wallets) {
           | [] => <div />
           | [wallet, ..._rest] =>
             <button
               onClick={_e =>
                 dispatch(
                   CodaProcess.Action.ChangeArgs([
                     "-run-snark-worker",
                     PublicKey.toString(wallet.key),
                   ]),
                 )
               }>
               {React.string(
                  "Do compressor on "
                  ++ AddressBook.getWalletName(addressbook, wallet.key),
                )}
             </button>
           };
         }}
    </SideBar.WalletQuery>
  </div>;
};
