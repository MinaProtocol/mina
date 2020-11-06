[@react.component]
let make =
    (
      ~profiles: array(ContentType.GenericMember.t),
      ~genesisMembers: array(ContentType.GenericMember.t),
      ~advisors: array(ContentType.GenericMember.t),
    ) => {
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
    <Contributors
      profiles
      genesisMembers
      advisors
      modalOpen
      switchModalState
    />
  </Page>;
};

Next.injectGetInitialProps(make, _ => {
  [|
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 1,
        "content_type": ContentType.TeamProfile.id,
        "order": "-fields.name",
      },
    ),
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 1,
        "content_type": ContentType.GenesisProfile.id,
        "order": "-fields.publishDate",
      },
    ),
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 1,
        "content_type": ContentType.Advisor.id,
        "order": "-fields.name",
      },
    ),
  |]
  |> Js.Promise.all
  |> Js.Promise.then_((results: array(ContentType.GenericMember.entries)) => {
       let profiles =
         results
         |> Array.map((e: ContentType.GenericMember.entries) => {
              e.items
              |> Array.map((e: ContentType.GenericMember.entry) => {e.fields})
            });

       Js.Promise.resolve({
         "profiles": profiles[0],
         "genesisMembers": profiles[1],
         "advisors": profiles[2],
       });
     })
});
