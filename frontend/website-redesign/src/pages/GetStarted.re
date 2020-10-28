module Styles = {
  open Css;

  let background =
    style([
      backgroundImage(
        `url("/static/img/BecomeAGenesisMemberBackground.jpg"),
      ),
      backgroundSize(`cover),
    ]);

  let knowledgebaseBackground =
    style([
      backgroundImage(`url("/static/img/backgrounds/KnowledgeBase.jpg")),
      backgroundSize(`cover),
      padding2(~v=`rem(12.), ~h=`zero),
    ]);

  let knowledgebaseContainer =
    style([
      marginLeft(`zero),
      media(Theme.MediaQuery.tablet, [paddingLeft(`rem(16.))]),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="Get Started"
      header="Mina makes it simple."
      copy={
        Some(
          "Interested and ready to take the next step? You're in the right place.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/GetStartedHeroDesktop.jpg",
        Theme.tablet: "/static/img/backgrounds/GetStartedHeroDesktop.jpg",
        Theme.mobile: "/static/img/backgrounds/GetStartedHeroDesktop.jpg",
      }
    />
    <ButtonBar
      kind=ButtonBar.GetStarted
      backgroundImg="/static/img/ButtonBarBackground.jpg"
    />
    <Spacer height=7. />
    <AlternatingSections
      backgroundImg="/static/img/MinaSimplePattern1.jpg"
      sections={
        AlternatingSections.Section.SimpleRow([|
          {
            AlternatingSections.Section.SimpleRow.title: "Run a Node",
            description: "Other protocols are so heavy they require intermediaries to run nodes, recreating the same old power dynamics. But Mina is light, so anyone can connect peer-to-peer and sync and verify the chain in seconds. Built on a consistent-sized cryptographic proof, the blockchain will stay accessible - even as it scales to millions of users.",
            buttonCopy: "Get Started",
            buttonUrl: `Internal("/docs/getting-started"),
            image: "/static/img/rowImages/RunANode.jpg",
          },
          {
            title: "Build on Mina",
            description: "Interested in building decentralized apps that use SNARKs to verify off-chain data with full verifiability, privacy and scaling? Just download the SDK, follow our step-by-step documentation and put your imagination to work.",
            buttonCopy: "Get Started",
            buttonUrl: `Internal("/docs/getting-started"),
            image: "/static/img/rowImages/BuildOnMina.jpg",
          },
          {
            title: "Join the Community",
            description: "Mina is an inclusive open source project uniting people around the world with a passion for decentralized technology and building what's next.",
            buttonCopy: "See what we're up to",
            buttonUrl: `Internal("/community"),
            image: "/static/img/rowImages/JoinCommunity.jpg",
          },
          {
            title: "Apply for a Grant",
            description: "From front-end sprints and protocol development to community building initiatives and content creation, our Grants Program invites you to help strengthen the network in exchange for Mina tokens.",
            buttonCopy: "Learn More",
            buttonUrl: `Internal("/docs/contributing#mina-grants"),
            image: "/static/img/rowImages/ApplyForGrant.jpg",
          },
        |])
      }
    />
    <div className=Styles.background>
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageRightCopyLeft,
          title: "Become a Genesis Member",
          copySize: `Small,
          description: {js|Calling all block producers, SNARK producers and community leaders. We’re looking for 1,000 participants to join the Genesis token grant program and form the backbone of Mina’s decentralized network."|js},
          textColor: Theme.Colors.white,
          image: "/static/img/GenesisCopy.jpg",
          background: Image("/static/img/BecomeAGenesisMemberBackground.jpg"),
          contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
          link:
            FeaturedSingleRow.Row.Button({
              FeaturedSingleRow.Row.buttonText: "Learn More",
              buttonColor: Theme.Colors.mint,
              buttonTextColor: Theme.Colors.digitalBlack,
              dark: true,
              href: `Internal("/genesis"),
            }),
        }
      />
    </div>
    <div className=Styles.knowledgebaseBackground>
      <Wrapped>
        <div className=Styles.knowledgebaseContainer> <KnowledgeBase /> </div>
      </Wrapped>
    </div>
    <ButtonBar
      kind=ButtonBar.HelpAndSupport
      backgroundImg="/static/img/ButtonBarBackground.jpg"
    />
  </Page>;
};
