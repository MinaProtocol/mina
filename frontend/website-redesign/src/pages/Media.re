[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="Media"
      header="We're on a mission."
      copy={
        Some(
          "To create a vibrant decentralized network and open programmable currency - so we can all participate, build, exchange and thrive.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/15_PressandMedia_1_750x1056_mobile.jpg",
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
