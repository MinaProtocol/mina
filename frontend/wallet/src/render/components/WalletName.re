[@react.component]
let make = (~pubkey, ~className="") => {
  let (addressBook, _) = React.useContext(AddressBookProvider.context);

  switch (AddressBook.lookup(addressBook, pubkey)) {
  | Some(name) =>
    <span className={Css.merge([Theme.Text.Body.regular, className])}>
      {React.string(name)}
    </span>
  | None =>
    <span className={Css.merge([Theme.Text.Body.mono, className])}>
      {React.string(PublicKey.prettyPrint(pubkey))}
    </span>
  };
};
