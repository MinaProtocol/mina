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
  </Page>;
};
