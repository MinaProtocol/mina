module SettingsContextType = {
  type t = (option(Settings.t), Settings.t => unit);

  let initialContext = (None, _ => ());
};

type t = SettingsContextType.t;
include ContextProvider.Make(SettingsContextType);
