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
        Theme.desktop: "/static/img/backgrounds/04_GetStarted_1_2880x1504.jpg",
        Theme.tablet: "/static/img/backgrounds/04_GetStarted_1_1536x1504_tablet.jpg",
        Theme.mobile: "/static/img/backgrounds/04_GetStarted_1_750x1056_mobile.jpg",
      }
    />
    <ButtonBar
      kind=ButtonBar.GetStarted
      backgroundImg="/static/img/ButtonBarBackground.png"
    />
    <AlternatingSections
      backgroundImg="/static/img/MinaSimplePattern1.png"
      sections={
        AlternatingSections.Section.FeaturedRow([|
          {
            AlternatingSections.Section.FeaturedRow.title: "Run a Node",
            description: "Other protocols are so heavy they require intermediaries to run nodes, recreating the same old power dynamics. But Mina is light, so anyone can connect peer-to-peer and sync and verify the chain in seconds. Built on a consistent-sized cryptographic proof, the blockchain will stay accessible - even as it scales to millions of users.",
            linkCopy: "Explore the Tech",
            linkUrl: "/",
            image: "/static/img/EasilyAccessible.png",
          },
          {
            title: "Build on Mina",
            description: "Interested in building decentralized apps that use SNARKs to verify off-chain data with full verifiability, privacy and scaling? Just download the SDK, follow our step-by-step documentation and put your imagination to work.",
            linkCopy: "Run a node",
            linkUrl: "/",
            image: "/static/img/TrulyDecentralized.png",
          },
          {
            title: "Join the Community",
            description: "Mina is an inclusive open source project uniting people around the world with a passion for decentralized technology and building what's next.",
            linkCopy: "See what we're up to",
            linkUrl: "/",
            image: "/static/img/LightChainHighSpeed.png",
          },
          {
            title: "Apply for a Grant",
            description: "From front-end sprints and protocol development to community building initiatives and content creation, our Grants Program invites you to help strengthen the network in exchange for Mina tokens.",
            linkCopy: "Learn More",
            linkUrl: "/",
            image: "/static/img/PrivateAndPowerful.png",
          },
        |])
      }
    />
  </Page>;
};
