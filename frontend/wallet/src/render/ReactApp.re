[@react.component]
let make = () => {
  let settingsValue = SettingsProvider.createContext();

  <SettingsProvider value=settingsValue>
    <ReasonApollo.Provider client=Apollo.faker>
      <Window>
        <Header />
        <Main> <SideBar /> <Router /> </Main>
        <Footer />
      </Window>
    </ReasonApollo.Provider>
  </SettingsProvider>;
};
