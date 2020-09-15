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
  <Page title="Coda Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Styles.page>
      <AnnouncementBanner>
        {React.string("Mainnet is live!")}
      </AnnouncementBanner>
      <HomepageHero />
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageLeftCopyRight,
          title: "It's Time to Own Our Future",
          description: "Why did we create the world's lightest blockchain? To rebalance the scales and give anyone with a smartphone the power to participate, build, exchange and thrive.",
          textColor: Theme.Colors.digitalBlack,
          image: "/static/img/NodeOpsTestnet.png",
          background: Image("/static/img/MinaSpectrumPrimary3.png"),
          contentBackground: Color(Theme.Colors.white),
          button: {
            FeaturedSingleRow.Row.buttonText: "More on Mina",
            buttonColor: Theme.Colors.orange,
            buttonTextColor: Theme.Colors.white,
            dark: false,
          },
        }
      />
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageRightCopyLeft,
          title: "Testnet",
          description: "Check out what's in beta, take on Testnet challenges and earn Testnet points.",
          textColor: Theme.Colors.white,
          image: "/static/img/NodeOpsTestnet.png",
          background: Image("/static/img/MinaSpectrumPrimarySilver.png"),
          contentBackground:
            Image("/static/img/TestnetContentBlockBackground.png"),
          button: {
            FeaturedSingleRow.Row.buttonText: "Go To Testnet",
            buttonColor: Theme.Colors.orange,
            buttonTextColor: Theme.Colors.white,
            dark: true,
          },
        }
      />
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageRightCopyLeft,
          title: "Genesis Program",
          description: "Calling all block producers, SNARK producers and community leaders. We're looking for 1,000 participants to join the Genesis token grant program and form the backbone of Mina's decentralized network.",
          textColor: Theme.Colors.white,
          image: "/static/img/GetStartedGenesisProgram.png",
          background: Image("/static/img/MinaSpectrumPrimarySilver.png"),
          contentBackground:
            Image("/static/img/TestnetContentBlockBackground.png"),
          button: {
            FeaturedSingleRow.Row.buttonText: "Learn More",
            buttonColor: Theme.Colors.mint,
            buttonTextColor: Theme.Colors.digitalBlack,
            dark: true,
          },
        }
      />
    </div>
  </Page>;
};
