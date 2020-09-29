module Styles = {
  open Css;
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
        background:
          Image("/static/img/community-page/CommunityBackground.png"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        button: {
          buttonColor: Theme.Colors.mint,
          buttonTextColor: Theme.Colors.white,
          buttonText: "Apply now",
          dark: true,
          href: "/genesis",
        },
      }>
      <Spacer height=4. />
      <Rule color=Theme.Colors.white />
      <Spacer height=4. />
      <Wrapped>
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
      </Wrapped>
    </FeaturedSingleRow>
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
