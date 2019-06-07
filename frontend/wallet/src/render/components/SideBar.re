open Tc;

module Styles = {
  open Css;

  let sidebar =
    style([
      width(`rem(14.)),
      overflow(`hidden),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      borderRight(`px(1), `solid, Theme.Colors.borderColor),
    ]);

  let footer = 
    style([
      padding2(~v=`rem(0.5), ~h=`rem(0.75)),
    ]);

  let addWalletLink =
    merge([
      Theme.Text.Body.regular,
      style([
        display(`inlineFlex),
        alignItems(`center),
        cursor(`default),
        color(Theme.Colors.tealAlpha(0.5)),
        padding2(~v=`zero, ~h=`rem(0.5)),
        hover([
          color(Theme.Colors.teal),
          backgroundColor(Theme.Colors.hyperlinkAlpha(0.15)),
          borderRadius(`px(2)),
        ]),
      ]),
    ]);
};

module Wallets = [%graphql
  {| query getWallets { ownedWallets {publicKey, balance{total}}} |}
];
module WalletQuery = ReasonApollo.CreateQuery(Wallets);

module AddWallet = [%graphql
  {|
  mutation addWallet {
      addWallet(input: {}) {
          publicKey
      }
  }
|}
];

module AddWalletMutation = ReasonApollo.CreateMutation(AddWallet);

[@react.component]
let make = () => {
  let (modalState, setModalState) = React.useState(() => None);
  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  <div className=Styles.sidebar>
    // TODO: Remove fetchPolicy="no-cache" after merge of
    // https://github.com/apollographql/reason-apollo/pull/196
      /* TODO(PM): push the active wallet onto router
        - not sure if best way to do this is a side effect when we get data
        from query. eg. check if a wallet is already selected, if not
        ReasonReact.Router.push("/wallet/" ++ PublicKey.uriEncode(firstWallet.key))
      */
      <WalletQuery fetchPolicy="no-cache" partialRefetch=true>
        {response =>
           switch (response.result) {
           | Loading => <Loader.Page><Loader /></Loader.Page>
           | Error(err) => React.string(err##message)
           | Data(data) =>
             <WalletList
               wallets={Array.map(~f=Wallet.ofGraphqlExn, data##ownedWallets)}
             />
           }}
      </WalletQuery>
      <div className=Styles.footer>
        <a
          className=Styles.addWalletLink
          onClick={_ => setModalState(_ => Some("My Wallet"))}
        >
          {React.string("+ Add wallet")}
        </a>
      </div>
      <AddWalletMutation>
        {(mutation, _) =>
           switch (modalState) {
           | None => React.null
           | Some(newWalletName) =>
             <AddWalletModal
               walletName=newWalletName
               setModalState
               onSubmit={name => {
                 let performMutation =
                   Task.liftPromise(() =>
                     mutation(~refetchQueries=[|"getWallets"|], ())
                   );
                 Task.perform(
                   performMutation,
                   ~f=
                     fun
                     | EmptyResponse => ()
                     | Errors(_) => print_endline("Error adding wallet")
                     | Data(data) =>
                       data##addWallet
                       |> Option.andThen(~f=addWallet => addWallet##publicKey)
                       |> Option.map(~f=pk => {
                            let key = PublicKey.ofStringExn(pk);
                            updateAddressBook(AddressBook.set(~key, ~name));
                          })
                       |> ignore,
                 );
               }}
             />
           }}
      </AddWalletMutation>
    </div>;
};
