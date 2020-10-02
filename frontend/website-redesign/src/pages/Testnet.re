module Styles = {
  open Css;

  let page =
    style([
      display(`flex),
      flexDirection(`column),
      overflowX(`hidden),
      height(`percent(100.)),
      height(`percent(100.)),
      selector("h4", [important(color(Theme.Colors.white))]),
    ]);

  let statusBadge =
    merge([
      Theme.Type.label,
      style([color(Theme.Colors.white), marginTop(`rem(4.5))]),
    ]);

  let leaderboardLink =
    style([width(`percent(100.)), textDecoration(`none)]);

  let leaderboardTextContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      marginTop(`rem(4.)),
      marginBottom(`rem(2.)),
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

  let disclaimer =
    merge([
      Theme.Type.disclaimer,
      style([
        display(`listItem),
        listStylePosition(`inside),
        marginBottom(`rem(14.)),
        marginTop(`rem(3.)),
      ]),
    ]);

  let leaderboardContainer =
    style([
      height(`rem(45.)),
      width(`percent(100.)),
      position(`relative),
      overflow(`hidden),
      display(`flex),
      flexWrap(`wrap),
      marginLeft(`auto),
      marginRight(`auto),
      justifyContent(`center),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Mina Protocol" footerColor=Theme.Colors.orange>
    <div className=Styles.page>
      <div className=Nav.Styles.spacer />
      <Hero
        title="Testnet"
        header="Secure the Network"
        copy={
          Some(
            {j|Push the boundaries of Mina’s testnet to help prepare for mainnet.|j},
          )
        }
        background={
          Theme.desktop: "/static/img/TestnetBackground.jpg",
          tablet: "/static/img/TestnetBackground.jpg",
          mobile: "/static/img/TestnetBackground.jpg",
        }>
        <p className=Styles.statusBadge>
          {React.string("Testnet Status: ")}
          <StatusBadge service=`Network />
        </p>
      </Hero>
      <Wrapped>
        <div className=Styles.leaderboardTextContainer>
          <h2 className=Theme.Type.h2>
            {React.string("Testnet Leaderboard")}
          </h2>
          <p className=Theme.Type.paragraph>
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
      <FeaturedSingleRow
        row={
          FeaturedSingleRow.Row.rowType: ImageRightCopyLeft,
          copySize: `Small,
          title: "Testnet Challenges",
          description: "Learn how to operate the protocol, while contributing to Mina's network resilience.",
          textColor: Theme.Colors.white,
          image: "/static/img/AboutHeroDesktopBackground.jpg",
          background: Image("/static/img/MinaSpectrumPrimarySilver.jpg"),
          contentBackground:
            Image("/static/img/TestnetContentBlockBackground.png"),
          button: {
            FeaturedSingleRow.Row.buttonText: "See the Latest Challenges",
            buttonColor: Theme.Colors.mint,
            buttonTextColor: Theme.Colors.digitalBlack,
            dark: true,
            href: `External("http://bit.ly/TestnetChallenges"),
          },
        }
      />
      <TestnetRetroModule />
      <ButtonBar
        kind=ButtonBar.HelpAndSupport
        backgroundImg="/static/img/ButtonBarBackground.jpg"
      />
    </div>
  </Page>;
};
