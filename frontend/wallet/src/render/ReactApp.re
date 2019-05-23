[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();

  <AddressBookProvider value=settingsValue>
    <ReasonApollo.Provider client=Apollo.faker>
      <Window>
        <Header />
        <Main> <SideBar /> <Router /> </Main>
        <Footer />
      </Window>
    </ReasonApollo.Provider>
  </AddressBookProvider>;
};
