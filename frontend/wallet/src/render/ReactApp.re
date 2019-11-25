// Move this into a context for easy i18n state access and setting
type action =
  | SetLocale(Locale.locale);

let initialState = Locale.En;

let intlReducer = (_, action) =>
  switch (action) {
  | SetLocale(locale) => locale
  };

[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let (isOnboarding, _) as onboardingValue =
    OnboardingProvider.createContext();
  let dispatch = CodaProcess.useHook();
  let toastValue = ToastProvider.createContext();
  
  let (locale, _) = intlReducer->React.useReducer(initialState);

  <AddressBookProvider value=settingsValue>
    <OnboardingProvider value=onboardingValue>
      <ProcessDispatchProvider value=dispatch>
        <ReasonApollo.Provider client=Apollo.client>
          // <ReactIntl.IntlProvider
          //   locale={locale->Locale.toString}
          //   messages={locale->Locale.translations->Locale.translationsToDict}>
            {isOnboarding
               ? <Onboarding />
               : <ToastProvider value=toastValue>
                 <Header />
                 <Main> <SideBar /> <Router /> </Main>
                 <Footer />
               </ToastProvider>}
          // </ReactIntl.IntlProvider>
        </ReasonApollo.Provider>
      </ProcessDispatchProvider>
    </OnboardingProvider>
  </AddressBookProvider>;
};