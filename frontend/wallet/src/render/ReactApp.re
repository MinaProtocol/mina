[@react.component]
let make = () => {
  let (settings, setSettings) = Hooks.useSettings();
  let initialContext = {
    settings: settings |> Tc.Result.toOption,
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
