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
      <HomepageAlternatingSections />
    </div>
  </Page>;
};
