open Tc;

let defaultName = "My Account";

module AddAccount = [%graphql
  {|
     mutation addWallet($password: String) {
         addWallet(input: {password: $password}) {
           publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
         }
     }
   |}
];

module AddAccountMutation = ReasonApollo.CreateMutation(AddAccount);

[@react.component]
let make = (~onClose) => {
  let (accountName, setName) = React.useState(() => defaultName);
  let (password, setPassword) = React.useState(() => "");

  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  <Modal title="New Account" onRequestClose=onClose>
    <div className=Modal.Styles.default>
      <Alert
        kind=`Info
        defaultMessage="You can rename or delete your account at anytime."
      />
      <Spacer height=1. />
      <TextField
        label="Name"
        onChange={value => setName(_ => value)}
        value=accountName
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
        <AddAccountMutation>
          {(mutation, _) =>
             <Button
               label="Create"
               style=Button.Green
               onClick={_ => {
                 let variables = AddAccount.make(~password, ())##variables;
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
                     | Errors(_) => print_endline("Error adding account")
                     | Data(data) => {
                         let key = data##addWallet##publicKey;
                         updateAddressBook(
                           AddressBook.set(~key, ~name=accountName),
                         );
                         onClose();
                       },
                 );
               }}
             />}
        </AddAccountMutation>
      </div>
    </div>
  </Modal>;
};