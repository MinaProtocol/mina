[@react.component]
let make = () => {
  let settingsValue = AddressBookProvider.createContext();

  let () =
    React.useEffect0(() => {
      let token = MainCommunication.listen();
      Some(() => MainCommunication.stopListening(token));
    });

  <AddressBookProvider value=settingsValue>
    <ReasonApollo.Provider client=Apollo.client>
      <CodaProcess>
        {_dispatch =>
           {<Window>
              <Header />
              <Main> <SideBar /> <Router /> </Main>
              <Footer />
            </Window>}}
      </CodaProcess>
    </ReasonApollo.Provider>
  </AddressBookProvider>;
};
