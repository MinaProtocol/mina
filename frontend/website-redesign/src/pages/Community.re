module Styles = {
  open Css;
  let background =
    style([
      backgroundImage(
        `url("/static/img/community-page/SectionCulture&Values.png"),
      ),
      backgroundSize(`cover),
    ]);
  let rowContainer = style([]);
  let h2 = merge([Theme.Type.h2, style([color(white)])]);
  let sectionSubhead =
    merge([
      Theme.Type.paragraphMono,
      style([
        color(white),
        letterSpacing(`pxFloat(-0.4)),
        marginTop(`rem(1.)),
        fontSize(`rem(1.18)),
        media(Theme.MediaQuery.tablet, [width(`rem(41.))]),
      ]),
    ]);
  //member profile css
  let profileRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      margin(`auto),
      selector("> :last-child", [marginBottom(`zero), marginRight(`zero)]),
      media(
        Theme.MediaQuery.tablet,
        [justifyContent(`flexStart), flexDirection(`row)],
      ),
    ]);

  let profile =
    style([
      marginRight(`rem(2.)),
      marginBottom(`rem(5.)),
      media(Theme.MediaQuery.tablet, [marginBottom(`zero)]),
    ]);
  //leaderboard css

  let disclaimer =
    merge([
      Theme.Type.disclaimer,
      style([paddingBottom(`rem(5.)), paddingTop(`rem(3.))]),
    ]);
  let leaderboardBackground =
    style([
      backgroundImage(`url("/static/img/backgrounds/SectionBackground.jpg")),
      backgroundSize(`cover),
    ]);

  let leaderboardContainer =
    style([
      height(`rem(65.)),
      width(`percent(100.)),
      position(`relative),
      overflow(`hidden),
      display(`flex),
      flexWrap(`wrap),
      marginLeft(`auto),
      marginRight(`auto),
      justifyContent(`center),
      media(Theme.MediaQuery.tablet, [height(`rem(43.))]),
    ]);

  let leaderboardTextContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      paddingTop(`rem(4.)),
      paddingBottom(`rem(2.)),
      width(`percent(100.)),
      media(
        Theme.MediaQuery.notMobile,
        [
          width(`percent(50.)),
          alignItems(`flexStart),
          justifyContent(`flexStart),
        ],
      ),
      selector(
        "button",
        [
          marginTop(`rem(2.)),
          important(maxWidth(`percent(50.))),
          width(`percent(100.)),
        ],
      ),
    ]);
  let leaderboardLink =
    style([
      width(`percent(100.)),
      textDecoration(`none),
      height(`percent(100.)),
    ]);
};

[@react.component]
let make = (~profiles) => {
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
      backgroundImg="/static/img/ButtonBarBackground.jpg"
    />
    <FeaturedSingleRow
      row=FeaturedSingleRow.Row.{
        rowType: ImageRightCopyLeft,
        copySize: `Large,
        title: "Genesis Program",
        description: "Calling all block producers and snark producers, community leaders and content creators! Join Genesis, meet great people, play an essential role in the network, and earn Mina tokens.",
        textColor: Theme.Colors.white,
        image: "/static/img/BlogLandingHero.jpg",
        background:
          Image("/static/img/community-page/CommunityBackground.jpg"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        link:
          {FeaturedSingleRow.Row.Button({
             buttonColor: Theme.Colors.mint,
             buttonTextColor: Theme.Colors.digitalBlack,
             buttonText: "Apply now",
             dark: true,
             href: `Internal("/genesis"),
           })},
      }>
      <Spacer height=4. />
      <Rule color=Theme.Colors.white />
      <Spacer height=4. />
      <h2 className=Styles.h2>
        {React.string("Genesis Founding Members")}
      </h2>
      <p className=Styles.sectionSubhead>
        {React.string(
           "Get to know some of the founding members working to strengthen the protocol and build our community.",
         )}
      </p>
      <Spacer height=6. />
      <div className=Styles.profileRow>
        {React.array(
           Array.map(
             (p: ContentType.GenesisProfile.t) => {
               <div className=Styles.profile>
                 <GenesisMemberProfile
                   key={p.name}
                   name={p.name}
                   photo={p.profilePhoto.fields.file.url}
                   quote={"\"" ++ p.quote ++ "\""}
                   location={p.memberLocation}
                   twitter={p.twitter}
                   github={p.github}
                   blogPost={p.blogPost.fields.slug}
                 />
               </div>
             },
             profiles,
           ),
         )}
      </div>
    </FeaturedSingleRow>
    <div className=Styles.leaderboardBackground>
      <Wrapped>
        <div className=Styles.leaderboardTextContainer>
          <h2 className=Theme.Type.h2>
            {React.string("Testnet Leaderboard")}
          </h2>
          <Spacer height=1. />
          <p className=Theme.Type.paragraphMono>
            {React.string(
               "Mina rewards community members for contributing to Testnet with Testnet Points, making them stronger applicants for the Genesis Program. ",
             )}
          </p>
          <Button
            bgColor=Theme.Colors.orange href={`Internal("/leaderboard")}>
            {React.string("See The Full Leaderboard")}
            <Icon kind=Icon.ArrowRightSmall />
          </Button>
        </div>
        <div className=Styles.leaderboardContainer>
          <a href="/leaderboard" className=Styles.leaderboardLink>
            <Leaderboard interactive=false />
          </a>
        </div>
        <p className=Styles.disclaimer>
          {React.string(
             "Testnet Points are designed solely to track contributions to the Testnet and are non-transferable. Testnet Points have no cash or monetary value and are not redeemable for any cryptocurrency or digital assets. We may amend or eliminate Testnet Points at any time.",
           )}
        </p>
      </Wrapped>
    </div>
    <QuoteSection
      small=false
      copy={js|My measure of a project isn't the quality of the tech. It’s the quality of the community. I wouldn't have been able to spin my node up if it weren't for the insanely great members that helped me. And that's something special.”|js}
      author="Jeff Flowers"
      authorTitle="Testnet Community Member"
      authorImg=""
      backgroundImg={
        Theme.desktop: "/static/img/MinaSpectrumPrimarySilver.jpg",
        Theme.tablet: "/static/img/MinaSpectrumPrimarySilver.jpg",
        Theme.mobile: "/static/img/MinaSpectrumPrimarySilver.jpg",
      }
    />
    <FeaturedSingleRow
      row={
        FeaturedSingleRow.Row.rowType: ImageLeftCopyRight,
        title: "Grants Program",
        copySize: `Small,
        description: "From front-end sprints and protocol development to community building initiatives and content creation, our Grants Program invites you to help strengthen the network in exchange for Mina tokens. ",
        textColor: Theme.Colors.white,
        image: "/static/img/MinaGrantsDevelopers.jpg",
        background: Color(Theme.Colors.white),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        link:
          FeaturedSingleRow.Row.Button({
            FeaturedSingleRow.Row.buttonText: "See All Opportunities",
            buttonColor: Theme.Colors.orange,
            buttonTextColor: Theme.Colors.white,
            dark: true,
            href: `Internal("/grants"),
          }),
      }>
      <div> <TypesOfGrants /> </div>
    </FeaturedSingleRow>
    <div className=Styles.background>
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageRightCopyLeft,
          title: "Our Culture",
          copySize: `Small,
          description: "It's hard to quantify, but it's not hard to see: in any community, culture is everything. It's the values that drive us. It's how we see the world and how we show up. Culture is who we are and becomes what we create.",
          textColor: Theme.Colors.black,
          image: "/static/img/community-page/09_Community_4_1504x1040.jpg",
          background:
            Image("/static/img/community-page/SectionCulture_Values.jpg"),
          contentBackground: Color(Theme.Colors.white),
          link:
            FeaturedSingleRow.Row.Label({
              FeaturedSingleRow.Row.labelText: "Read the Code of Conduct",
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
      </FeaturedSingleRow>
    </div>
  </Page>;
};

Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 1,
      "content_type": ContentType.GenesisProfile.id,
      "order": "-fields.publishDate",
      "limit": 3,
    },
  )
  |> Promise.map((entries: ContentType.GenesisProfile.entries) => {
       let profiles =
         Array.map(
           (e: ContentType.GenesisProfile.entry) => e.fields,
           entries.items,
         );
       {"profiles": profiles};
     })
});
