[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let (isOnboarding, _) as onboardingValue =
    OnboardingProvider.createContext();
  let dispatch = CodaProcess.useHook();
  let toastValue = ToastProvider.createContext();

  <AddressBookProvider value=settingsValue>
    <OnboardingProvider value=onboardingValue>
      <ProcessDispatchProvider value=dispatch>
        <ReasonApollo.Provider client=Apollo.client>
          {isOnboarding
             ? <Onboarding />
             : <ToastProvider value=toastValue>
                 <Header />
                 <Main> <SideBar /> <Router /> </Main>
                 <Footer />
               </ToastProvider>}
        </ReasonApollo.Provider>
      </ProcessDispatchProvider>
    </OnboardingProvider>
  </AddressBookProvider>;
};
