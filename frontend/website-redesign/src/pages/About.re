[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="About"
      header="We're on a mission."
      copy=Some("To create a vibrant decentralized network and open programmable currency - so we can all participate, build, exchange and thrive.")
      background={
        Theme.desktop: "/static/img/AboutHeroDesktopBackground.jpg",
        Theme.tablet: "/static/img/AboutHeroTabletBackground.jpg",
        Theme.mobile: "/static/img/AboutHeroMobileBackground.jpg",
      }
    />
    <AboutpageRows />
    <QuoteSection />
    <SecuredBySection />
    <Contributors />
    <Investors />
  </Page>;
};
