module Styles = {
  open Css;
  let page =
    style([
      display(`flex),
      flexDirection(`column),
      overflowX(`hidden),
      height(`percent(100.)),
      height(`percent(100.)),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Mina Protocol" footerColor=Theme.Colors.orange>
    <div className=Styles.page>
      <HomepageHero backgroundImg="/static/img/HeroSectionBackground.jpg" />
      <BlockchainComparison />
      <AlternatingSections
        backgroundImg="/static/img/MinaSimplePattern1.jpg"
        sections={
          AlternatingSections.Section.FeaturedRow([|
            {
              AlternatingSections.Section.FeaturedRow.title: "Easily Accessible, Now & Always",
              description: "Other protocols are so heavy they require intermediaries to run nodes, recreating the same old power dynamics. But Mina is light, so anyone can connect peer-to-peer and sync and verify the chain in seconds. Built on a consistent-sized cryptographic proof, the blockchain will stay accessible - even as it scales to millions of users.",
              linkCopy: "Explore the Tech",
              linkUrl: "/tech",
              image: "/static/img/EasilyAccessible.png",
            },
            {
              title: "Truly Decentralized, with Full Nodes like Never Before",
              description: "With Mina, anyone who's syncing the chain is also validating transactions like a full node. Mina's design means any participant can take part in proof-of-stake consensus, have access to strong censorship-resistance and secure the blockchain.",
              linkCopy: "Run a Node",
              linkUrl: "/docs/node-operator",
              image: "/static/img/TrulyDecentralized.png",
            },
            {
              title: "Light Chain, High Speed",
              description: "Other protocols are weighed down by terabytes of private user data and network congestion. But on Mina's 22kb chain, apps execute as fast as your bandwidth can carry them - paving the way for a seamless end user experience and mainstream adoption.",
              linkCopy: "Explore the Tech",
              linkUrl: "/tech",
              image: "/static/img/LightChainHighSpeed.png",
            },
            {
              title: "Private & Powerful Apps, Thanks to Snapps",
              description: "Mina enables an entirely new category of applications - Snapps. These SNARK-powered decentralized apps are optimized for efficiency, privacy and scalability. Logic and data are computed off-chain, then verified on-chain by the end user's device. And information is validated without disclosing specifics, so people stay in control of their personal data.",
              linkCopy: "Build on Mina",
              linkUrl: "/docs/snapps",
              image: "/static/img/PrivateAndPowerful.png",
            },
            {
              title: "Programmable Money, For All",
              description: "Mina's peer-to-peer permissionless network empowers participants to build and interact with tokens directly - without going through a centralized wallet, exchange or intermediary. And payments can be made in Mina's native asset, stablecoin or in user-generated programmable tokens - opening a real world of possibilities.",
              linkCopy: "Build on Mina",
              linkUrl: "/docs",
              image: "/static/img/ProgrammableMoney.png",
            },
          |])
        }
      />
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageLeftCopyRight,
          title: "It's Time to Own Our Future",
          copySize: `Small,
          description: "Why did we create the world's lightest blockchain? To rebalance the scales and give anyone with a smartphone the power to participate, build, exchange and thrive.",
          textColor: Theme.Colors.digitalBlack,
          image: "/static/img/homepage-cta.jpg",
          background: Image("/static/img/MinaSpectrumPrimary3.jpg"),
          contentBackground: Color(Theme.Colors.white),
          link:
            FeaturedSingleRow.Row.Button({
              FeaturedSingleRow.Row.buttonText: "More on Mina",
              buttonColor: Theme.Colors.orange,
              buttonTextColor: Theme.Colors.white,
              dark: false,
              href: `Internal("/about"),
            }),
        }
      />
      <BlogModule source=`Press />
    </div>
  </Page>;
};
