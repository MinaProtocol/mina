open Tc;

let defaultName = "My Wallet";

module AddWallet = [%graphql
  {|
     mutation addWallet($password: String) {
         addWallet(input: {password: $password}) {
           publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
         }
     }
   |}
];

module AddWalletMutation = ReasonApollo.CreateMutation(AddWallet);

[@react.component]
let make = (~onClose) => {
  let (walletName, setName) = React.useState(() => defaultName);
  let (password, setPassword) = React.useState(() => "");

  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  <Modal title="Add Wallet" onRequestClose=onClose>
    <div className=Modal.Styles.default>
      <Alert
        kind=`Info
        message="You can change the name or delete the wallet later."
      />
      <Spacer height=1. />
      <TextField
        label="Name"
        onChange={value => setName(_ => value)}
        value=walletName
      />
      <Spacer height=0.5 />
      <TextField
        label="Pass"
        type_="password"
        onChange={value => setPassword(_ => value)}
        value=password
      />
      <Spacer height=1.5 />
      <div className=Css.(style([display(`flex)]))>
        <Button label="Cancel" style=Button.Gray onClick={_ => onClose()} />
        <Spacer width=1. />
        <AddWalletMutation>
          {(mutation, _) =>
             <Button
               label="Create"
               style=Button.Green
               onClick={_ => {
                 let variables = AddWallet.make(~password, ())##variables;
                 let performMutation =
                   Task.liftPromise(() =>
                     mutation(
                       ~variables,
                       ~refetchQueries=[|"getWallets"|],
                       (),
                     )
                   );
                 Task.perform(
                   performMutation,
                   ~f=
                     fun
                     | EmptyResponse => ()
                     | Errors(_) => print_endline("Error adding wallet")
                     | Data(data) => {
                         let key = data##addWallet##publicKey;
                         updateAddressBook(AddressBook.set(~key, ~name=walletName));
                         onClose();
                       },
                 );
               }}
             />}
        </AddWalletMutation>
      </div>
    </div>
  </Modal>;
};
