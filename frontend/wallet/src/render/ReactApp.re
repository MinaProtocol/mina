[@react.component]
let make = () => {
  let (activeWallet, setActiveWallet) = React.useState(() => None);
  let activeWalletContext = (
    activeWallet,
    newWallet => setActiveWallet(_ => Some(newWallet)),
  );

  let settingsValue = SettingsProvider.createContext();

  <ActiveWalletProvider value=activeWalletContext>
    <SettingsProvider value=settingsValue>
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
