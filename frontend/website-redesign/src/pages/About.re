[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="About"
      header="We're on a mission."
      copy={
        Some(
          "To create a vibrant decentralized network and open programmable currency - so we can all participate, build, exchange and thrive.",
        )
      }
      background={
        Theme.desktop: "/static/img/AboutHeroDesktopBackground.jpg",
        Theme.tablet: "/static/img/AboutHeroTabletBackground.jpg",
        Theme.mobile: "/static/img/AboutHeroMobileBackground.jpg",
      }
    />
    <AboutpageRows />
    <QuoteSection
      copy="What attracted me was a small, scalable blockchain that's still independently verifiable on small nodes.\""
      author="Naval Ravikant"
      authorTitle="AngelList Co-Founder, O(1) Labs Investor"
      authorImg="/static/img/headshots/naval.jpg"
      backgroundImg={
        Theme.desktop: "/static/img/SectionQuoteDesktop.jpg",
        Theme.tablet: "/static/img/SectionQuoteTablet.jpg",
        Theme.mobile: "/static/img/SectionQuoteMobile.png",
      }
    />
    <SecuredBySection />
    <Contributors />
    <Investors />
  </Page>;
};
