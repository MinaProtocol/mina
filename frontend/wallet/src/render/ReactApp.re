[@react.component]
let make = (~message) => {
  let (_path, settingsOrError, _setSettingsOrError) = Page.useRoute();
  <ReasonApollo.Provider client=Apollo.client>
    <Window>
      <Header />
      {React.string(message)}
      <Footer
        stakingKey={PublicKey.ofStringExn("131243123")}
        settings={
          switch (settingsOrError) {
          | `Settings(settings) => settings
          | _ => failwith("Bad; we need settings")
          }
        }
      />
    </Window>
  </ReasonApollo.Provider>;
};
