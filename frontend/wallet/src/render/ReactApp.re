[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let onboardingValue = OnboardingProvider.createContext();
  let toastValue = ToastProvider.createContext();

  let dispatch = CodaProcess.useHook();

  <AddressBookProvider value=settingsValue>
    <OnboardingProvider value=onboardingValue>
      <ProcessDispatchProvider value=dispatch>
        <ReasonApollo.Provider client=Apollo.client>
          <Onboarding />
          <ToastProvider value=toastValue>
            <Header />
            <Main> <SideBar /> <Router /> </Main>
            <Footer />
          </ToastProvider>
        </ReasonApollo.Provider>
      </ProcessDispatchProvider>
    </OnboardingProvider>
  </AddressBookProvider>;
};
