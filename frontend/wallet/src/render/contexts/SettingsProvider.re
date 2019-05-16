open Tc;

module SettingsContextType = {
  type t = (
    option(Settings.t),
    (option(Settings.t) => option(Settings.t)) => unit,
  );

  let initialContext = (None, _ => ());
};

type t = SettingsContextType.t;
include ContextProvider.Make(SettingsContextType);

let createContext = () => {
  let (settings, setSettings) =
    React.useState(() => Result.toOption(SettingsRenderer.loadSettings()));

  (
    settings,
    createNewSettings =>
      setSettings(settings =>
        createNewSettings(settings)
        |> Option.map(~f=newSettings => {
             Task.attempt(
               ~f=_ => (),
               SettingsRenderer.saveSettings(newSettings),
             );
             newSettings;
           })
      ),
  );
};
