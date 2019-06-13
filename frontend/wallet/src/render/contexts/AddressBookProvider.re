open Tc;

module AddressBookContextType = {
  type t = (AddressBook.t, (AddressBook.t => AddressBook.t) => unit);

  let initialContext = (AddressBook.empty, _ => ());
};

type t = AddressBookContextType.t;
include ContextProvider.Make(AddressBookContextType);

let createContext = () => {
  let localStorageKeyName = "addressbook";

  let (settings, setAddressBook) =
    React.useState(() =>
      localStorageKeyName
      |> Bindings.LocalStorage.getItem
      |> Js.Nullable.toOption
      |> Option.map(~f=AddressBook.fromJsonString)
      |> Option.withDefault(~default=AddressBook.empty)
    );

  (
    settings,
    createNewAddressBook =>
      setAddressBook(settings => {
        let newAddressBook = createNewAddressBook(settings);
        Bindings.LocalStorage.setItem(
          localStorageKeyName,
          AddressBook.toJsonString(newAddressBook),
        );
        newAddressBook;
      }),
  );
};
