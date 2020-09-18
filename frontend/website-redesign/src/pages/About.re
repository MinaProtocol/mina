[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <AboutpageHero />
    <AboutpageRows />
    <QuoteSection />
    <SecuredBySection />
    <Contributors />
    <Investors />
  </Page>;
};
