[@react.component]
let make = () => {
  let (settings, setSettings) = Hooks.useSettings();
  let settingsContext = (
    Tc.Result.toOption(settings),
    newSettings => setSettings(Ok(newSettings)),
  );

  let (activeWallet, setActiveWallet) = React.useState(() => None);
  let activeWalletContext = (
    activeWallet,
    newWallet => setActiveWallet(_ => Some(newWallet)),
  );

  <ActiveWalletProvider value=activeWalletContext>
    <SettingsProvider value=settingsContext>
      <ReasonApollo.Provider client=Apollo.faker>
        <Window>
          <Header />
          <Main> <SideBar /> <Router /> </Main>
          <Footer />
        </Window>
      </ReasonApollo.Provider>
    </SettingsProvider>
  </ActiveWalletProvider>;
};
