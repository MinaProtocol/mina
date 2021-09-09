module LocaleContextType = {
  type t = (Locale.locale, Locale.action => unit);

  let initialContext = (Locale.En, _ => ());
};

type t = LocaleContextType.t;
include ContextProvider.Make(LocaleContextType);

let createContext = () => {
  Locale.useLocale();
};