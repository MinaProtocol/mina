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

  let footer = style([padding2(~v=`rem(0.5), ~h=`rem(0.75))]);

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

// TODO: Don't use an empty password
module AddWallet = [%graphql
  {|
    mutation addWallet {
        addWallet(input: {password: ""}) {
          publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
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
    <WalletList />
    <div className=Styles.footer>
      <a
        className=Styles.addWalletLink
        onClick={_ => setModalState(_ => Some("My Wallet"))}>
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
                   | Data(data) => {
                       let key = data##addWallet##publicKey;
                       updateAddressBook(AddressBook.set(~key, ~name));
                     },
               );
             }}
           />
         }}
    </AddWalletMutation>
  </div>;
};
