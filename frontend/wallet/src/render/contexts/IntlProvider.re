type action =
  | SetLocale(Locale.locale);

let initialState = Locale.Vn;

let intlReducer = (_, action) =>
  switch (action) {
  | SetLocale(locale) => locale
  };

// Todo: Pass setLocale down to children
let make = (~children) => {
  let (locale, _) = intlReducer->React.useReducer(initialState);

  <ReactIntl.IntlProvider
    locale={locale->Locale.toString}
    messages={locale->Locale.translations->Locale.translationsToDict}>
    ...children
  </ReactIntl.IntlProvider>;
} /* React.Context.provider(intlContext)*/;