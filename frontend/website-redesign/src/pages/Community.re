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
        Theme.desktop: "/static/img/AboutHeroDesktopBackground.jpg",
        Theme.tablet: "/static/img/AboutHeroTabletBackground.jpg",
        Theme.mobile: "/static/img/AboutHeroMobileBackground.jpg",
      }
    />
    <ButtonBar
      kind=ButtonBar.CommunityLanding
      backgroundImg="/static/img/ButtonBarBackground.png"
    />
  </Page>;
};
