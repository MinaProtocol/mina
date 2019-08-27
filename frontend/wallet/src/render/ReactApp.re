[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();
  let dispatch = CodaProcess.useHook();

  <AddressBookProvider value=settingsValue>
    <ProcessDispatchProvider value=dispatch>
      <ReasonApollo.Provider client=Apollo.client>
        <Header />
        <Main> <SideBar /> <Router /> </Main>
        <Footer />
      </ReasonApollo.Provider>
    </ProcessDispatchProvider>
  </AddressBookProvider>;
};
