[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let (isOnboarding, _) as onboardingValue =
    OnboardingProvider.createContext();
  let dispatch = CodaProcess.useHook();
  let toastValue = ToastProvider.createContext();
  let daemonValue = DaemonProvider.createContext();
  let (locale, dispatchLocale) = LocaleProvider.createContext();

  <AddressBookProvider value=settingsValue>
    <OnboardingProvider value=onboardingValue>
      <ProcessDispatchProvider value=dispatch>
        <DaemonProvider value=daemonValue>
          <Apollo.Provider>
            <LocaleProvider value=(locale, dispatchLocale)>
              <ReactIntl.IntlProvider
                locale={locale->Locale.toString}
                messages={
                  locale->Locale.getTranslations->Locale.translationsToDict
                }>
                {isOnboarding
                   ? <Onboarding />
                   : <ToastProvider value=toastValue>
                       <Header />
                       <Main> <SideBar /> <Router /> </Main>
                       <Footer />
                     </ToastProvider>}
              </ReactIntl.IntlProvider>
            </LocaleProvider>
          </Apollo.Provider>
        </DaemonProvider>
      </ProcessDispatchProvider>
    </OnboardingProvider>
  </AddressBookProvider>;
};
