[@react.component]
let make = () => {
  let (settings, setSettings) = Hooks.useSettings();
  let initialContext = {
    SettingsProvider.settings: Tc.Result.toOption(settings),
    setSettings: newSettings => {
      setSettings(Ok(newSettings));
    },
  };
  <SettingsProvider value=initialContext>
    <ReasonApollo.Provider client=Apollo.client>
      <Window>
        <Header />
        <Main> <SideBar /> <Router /> </Main>
        <Footer />
      </Window>
    </ReasonApollo.Provider>
  </SettingsProvider>;
};
