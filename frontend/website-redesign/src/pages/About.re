[@react.component]
let make = (~profiles) => {
  let (modalOpen, setModalOpen) = React.useState(_ => false);

  let switchModalState = () => {
    setModalOpen(_ => !modalOpen);
  };

  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="About"
      header={Some("We're on a mission.")}
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
        Theme.mobile: "/static/img/SectionQuoteMobile.jpg",
      }
    />
    <SecuredBySection />
    <Contributors profiles modalOpen switchModalState />
    <Investors />
  </Page>;
};

Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 1,
      "content_type": ContentType.TeamProfile.id,
      "order": "-fields.name",
    },
  )
  |> Promise.map((entries: ContentType.TeamProfile.entries) => {
       let profiles =
         Array.map(
           (e: ContentType.TeamProfile.entry) => e.fields,
           entries.items,
         );
       {"profiles": profiles};
     })
});
