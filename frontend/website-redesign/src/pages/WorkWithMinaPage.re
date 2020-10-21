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
        href=`Scroll_to_top
        bgColor=Theme.Colors.digitalBlack
        width={`rem(15.)}>
        {React.string("See All Opportunities")}
        <Icon kind=Icon.ArrowRightMedium size=1. />
      </Button>
    </Hero>
    <Statement
      title="Our Mission"
      copy={js|To create a vibrant decentralized network and open programmable currency — so anyone with a smartphone can participate, build, exchange and thrive.|js}
      backgroundImg={
        Theme.desktop: "/static/img/SectionQuoteDesktop.jpg",
        Theme.tablet: "/static/img/SectionQuoteTablet.jpg",
        Theme.mobile: "/static/img/SectionQuoteMobile.png",
      }
    />
    <SimpleRow
      img="/static/img/mina-cubes.gif"
      title={js|Mina’s Technology|js}
      copy={js|Mina is a layer one protocol designed to deliver on the original promise of blockchain — true decentralization, scale and security. But rather than apply brute computing force, Mina uses advanced cryptography and recursive zk-SNARKs.|js}
      buttonCopy="Learn More"
      buttonUrl="/docs"
    />
  </Page>;
};
