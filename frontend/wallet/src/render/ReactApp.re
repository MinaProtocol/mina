[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let (isOnboarding, _) as onboardingValue =
    OnboardingProvider.createContext();
  let dispatch = CodaProcess.useHook();

  <AddressBookProvider value=settingsValue>
    <OnboardingProvider value=onboardingValue>
      <ProcessDispatchProvider value=dispatch>
        <ReasonApollo.Provider client=Apollo.client>
          <ReactIntl.IntlProvider>
            {isOnboarding
               ? <Onboarding />
               : <>
                   <Header />
                   <Main> <SideBar /> <Router /> </Main>
                   <Footer />
                 </>}
          </ReactIntl.IntlProvider>
        </ReasonApollo.Provider>
      </ProcessDispatchProvider>
    </OnboardingProvider>
  </AddressBookProvider>;
};