[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let onboardingValue = OnboardingProvider.createContext();
  let dispatch = CodaProcess.useHook();
  let toastValue = ToastProvider.createContext();

  <ToastProvider value=toastValue>
    <AddressBookProvider value=settingsValue>
      <OnboardingProvider value=onboardingValue>
        <ProcessDispatchProvider value=dispatch>
          <ReasonApollo.Provider client=Apollo.client>
            <Onboarding />
            <Header />
            <Main> <SideBar /> <Router /> </Main>
            <Footer />
          </ReasonApollo.Provider>
        </ProcessDispatchProvider>
      </OnboardingProvider>
    </AddressBookProvider>
  </ToastProvider>;
};
