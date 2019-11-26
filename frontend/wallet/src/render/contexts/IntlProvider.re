type action =
  | SetLocale(Locale.locale);

let initialState = Locale.Vn;

let intlReducer = (_, action) =>
  switch (action) {
  | SetLocale(locale) => locale
  };

module IntlContextType = {
  type t = (Locale.locale, action => unit);

  let initialContext = (Locale.En, _ => ());
};

// TODO Somehow insert ReactIntl.Provider here...

type t = IntlContextType.t;
include ContextProvider.Make(IntlContextType);

let createContext = () => {
  let (locale, setLocale) = intlReducer->React.useReducer(initialState);
  (locale, setLocale);
};
