[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <Hero
      title="About"
      header="We're on a mission."
      copy="To create a vibrant decentralized network and open programmable currency - so we can all participate, build, exchange and thrive."
    />
    <AboutpageRows />
    <QuoteSection />
    <SecuredBySection />
    <Contributors />
    <Investors />
  </Page>;
};
