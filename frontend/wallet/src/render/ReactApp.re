[@react.component]
let make = () => {
  <ReasonApollo.Provider client=Apollo.client>
    <Window>
      <Header />
      <Main> <SideBar /> <Router /> </Main>
      <Footer />
    </Window>
  </ReasonApollo.Provider>;
};
