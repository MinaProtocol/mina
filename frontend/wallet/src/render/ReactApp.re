[@react.component]
let make = () => {
  let (settings, setSettings) = Hooks.useSettings();
  let settingsContext = (
    Tc.Result.toOption(settings),
    newSettings => setSettings(Ok(newSettings)),
  );

  // TODO: route to the initial wallet
  ReasonReact.Router.push("/");

  <SettingsProvider value=settingsContext>
    <ReasonApollo.Provider client=Apollo.faker>
      <Window>
        <Header />
        <Main> <SideBar /> <Router /> </Main>
        <Footer />
      </Window>
    </ReasonApollo.Provider>
  </SettingsProvider>;
};
