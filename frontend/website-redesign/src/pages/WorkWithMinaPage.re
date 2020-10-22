module Styles = {
  open Css;

  let cultureBackground =
    style([
      backgroundImage(
        `url("/static/img/backgrounds/WorkWithMinaOurCulture.jpg"),
      ),
      backgroundSize(`cover),
      paddingTop(`rem(6.)),
      media(Theme.MediaQuery.desktop, [paddingTop(`rem(8.))]),
      media(Theme.MediaQuery.desktop, [paddingTop(`rem(12.))]),
    ]);
};

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
        href={`External("mailto:jobs@o1labs.org")}
        bgColor=Theme.Colors.digitalBlack
        width={`rem(15.)}>
        {React.string("Send us your resume")}
        <Icon kind=Icon.ArrowRightMedium size=1. />
      </Button>
    </Hero>
    <Statement
      title="Our Mission"
      small=false
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
      buttonUrl="/tech"
    />
    <div className=Styles.cultureBackground>
      <FeaturedSingleRowFull
        row={
          FeaturedSingleRowFull.Row.rowType: ImageRightCopyLeft,
          header: None,
          title: "Our Culture",
          description: "It's hard to quantify, but it's not hard to see: in any community, culture is everything. It's the values that drive us. It's how we see the world and how we show up. Culture is who we are and becomes what we create.",
          textColor: Theme.Colors.black,
          image: "/static/img/community-page/09_Community_4_1504x1040.jpg",
          background: Image(""),
          contentBackground: Color(Theme.Colors.white),
          link:
            FeaturedSingleRowFull.Row.Label({
              FeaturedSingleRowFull.Row.labelText: "Read the Code of Conduct",
              labelColor: Theme.Colors.orange,
              href: `External(Constants.codeOfConductUrl),
            }),
        }>
        <Spacer height=4. />
        <Rule color=Theme.Colors.digitalBlack />
        <Spacer height=4. />
        <CultureGrid
          title="What Unites Us"
          description=None
          sections=[|
            {
              title: "Respect",
              copy: "Above all, we respect each other. That's why we stand for equality and fairness. Why we're committed to decentralization. And why we strive to always be inclusive and accessible.",
            },
            {
              title: "Curiosity",
              copy: "It's our obsession to understand and solve. Our attraction to big questions and impossible problems. Our love of collaboration and exploration. It's our imagination, at work.",
            },
            {
              title: "Excellence",
              copy: "We demand the best of ourselves. Elegant solutions. Symphonic systems. Technical beauty. We're committed to creating tech people can depend on. We enjoy the process and deliver results.",
            },
            {
              title: "Openness",
              copy: "We're all about being there for our community. Empowering people with helpful information. Sharing where we are. Owning our mistakes. And serving our vision with humility.",
            },
          |]
        />
        <Spacer height=7. />
      </FeaturedSingleRowFull>
    </div>
  </Page>;
};
