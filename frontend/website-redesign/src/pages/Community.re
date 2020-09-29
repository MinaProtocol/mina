[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="Community"
      header="Welcome"
      copy={
        Some(
          "We're an inclusive community uniting people around the world with a passion for decentralized blockchain.",
        )
      }
      background={
        Theme.desktop: "/static/img/community-page/09_Community_1_2880x1504.jpg",
        Theme.tablet: "/static/img/community-page/09_Community_1_1536x1504_tablet.jpg",
        Theme.mobile: "/static/img/community-page/09_Community_1_750x1056_mobile.jpg",
      }
    />
    <ButtonBar
      kind=ButtonBar.CommunityLanding
      backgroundImg="/static/img/ButtonBarBackground.png"
    />
    <FeaturedSingleRow
      row=FeaturedSingleRow.Row.{
        rowType: ImageRightCopyLeft,
        copySize: `Large,
        title: "Genesis Program",
        description: "Calling all block producers and snark producers, community leaders and content creators! Join Genesis, meet great people, play an essential role in the network, and earn Mina tokens.",
        textColor: Theme.Colors.white,
        image: "/static/img/BlogLandingHero.png",
        background: Image("/static/img/MinaSimplePattern1.png"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        button: {
          buttonColor: Theme.Colors.mint,
          buttonTextColor: Theme.Colors.white,
          buttonText: "Apply now",
          dark: true,
          href: "/genesis",
        },
      }
    />
  </Page>;
};
