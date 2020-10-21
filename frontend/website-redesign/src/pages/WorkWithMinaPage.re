[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title=""
      header="Work with Mina"
      copy={
        Some(
          {js|Interested in growing the world’s lightest, most accessible blockchain?|js},
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/WorkWithMinaHeroDesktop.jpg",
        Theme.tablet: "/static/img/backgrounds/WorkWithMinaHeroTablet.jpg",
        Theme.mobile: "/static/img/backgrounds/WorkWithMinaHeroMobile.jpg",
      }>
      <Spacer height=1.5 />
      <Button
        href=`Scroll_to_top bgColor=Theme.Colors.black width={`rem(14.)}>
        {React.string("See All Opportunities")}
        <Icon kind=Icon.ArrowRightMedium size=1. />
      </Button>
    </Hero>
  </Page>;
};
