[@react.component]
let make = (~pubkey) => {
  let (addressBook, _) =
    React.useContext(AddressBookProvider.context);

  switch (AddressBook.lookup(addressBook, pubkey)) {
  | Some(name) =>
    <span className=Theme.Text.Body.regular> {React.string(name)} </span>
  | None =>
    <span className=Theme.Text.Body.mono>
      {React.string(PublicKey.prettyPrint(pubkey))}
    </span>
  };
};
