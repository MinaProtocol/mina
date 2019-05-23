open Tc;

module AddressBookContextType = {
  type t = (Settings.t, (Settings.t => Settings.t) => unit);

  let initialContext = (Settings.empty, _ => ());
};

type t = AddressBookContextType.t;
include ContextProvider.Make(AddressBookContextType);

let createContext = () => {
  let localStorageKeyName = "addressbook";

  let (settings, setSettings) =
    React.useState(() =>
      localStorageKeyName
      |> Bindings.LocalStorage.getItem
      |> Js.Nullable.toOption
      |> Option.map(~f=Settings.fromJsonString)
      |> Option.withDefault(~default=Settings.empty)
    );

  (
    settings,
    createNewSettings =>
      setSettings(settings => {
        let newSettings = createNewSettings(settings);
        Bindings.LocalStorage.setItem(
          localStorageKeyName,
          Settings.toJsonString(newSettings),
        );
        newSettings;
      }),
  );
};
