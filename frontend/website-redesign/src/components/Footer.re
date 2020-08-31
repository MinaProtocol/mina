module Styles = {
  open Css;
  let footerContainer =
    style([
      left(`zero),
      bottom(`zero),
      width(`percent(100.)),
      height(`rem(106.)),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      backgroundImage(`url("/static/img/FooterBackground.png")),
      media(
        Theme.MediaQuery.tablet,
        [padding2(~v=`rem(5.5), ~h=`rem(9.5))],
      ),
    ]);
  let innerContainer =
    style([
      display(`flex),
      flexDirection(`column),
      media(Theme.MediaQuery.desktop, [flexDirection(`row)]),
    ]);
  let leftSide =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      alignContent(`spaceBetween),
      media(Theme.MediaQuery.desktop, [marginRight(`rem(10.6))]),
    ]);
  let emailInputSection =
    style([media(Theme.MediaQuery.desktop, [marginTop(`rem(10.5))])]);
  let logo =
    style([
      height(`rem(3.1)),
      width(`rem(11.)),
      marginBottom(`rem(4.)),
    ]);
  let label = merge([Theme.Type.h4, style([color(white)])]);
  let connectLabel =
    merge([Theme.Type.h4, style([color(white), marginTop(`rem(2.12))])]);
  let paragraph = merge([Theme.Type.paragraph, style([color(white)])]);
  let emailSubtext =
    merge([
      Theme.Type.paragraph,
      style([color(white), marginTop(`zero), marginBottom(`px(8))]),
    ]);
};

module SocialIcons = {
  module Styles = {
    open Css;
    let iconsRow =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`spaceBetween),
        alignContent(`center),
        width(`rem(14.)),
        height(`rem(2.)),
        color(white),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.iconsRow>
      <Icon kind=Icon.Discord size=2. />
      <Icon kind=Icon.Twitter size=2. />
      <Icon kind=Icon.Facebook size=2. />
      <Icon kind=Icon.Telegram size=2. />
      <Icon kind=Icon.WeChat size=2. />
    </div>;
  };
};

module FooterLinks = {
  module Styles = {
    open Css;
    let linksGrid =
      style([
        display(`grid),
        gridTemplateColumns([
          `repeat((`num(2), `minmax((`rem(11.), `rem(11.5))))),
        ]),
        gridColumnGap(`rem(1.75)),
        gridRowGap(`rem(3.1)),
        marginTop(`rem(4.)),
        media(
          Theme.MediaQuery.tablet,
          [
            marginTop(`rem(5.8)),
            gridRowGap(`rem(3.)),
            gridTemplateColumns([
              `repeat((`num(3), `minmax((`rem(11.), `rem(11.5))))),
            ]),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
          [marginTop(`rem(0.)), width(`rem(36.5)), height(`rem(30.))],
        ),
      ]);
    let linksGroup =
      style([
        display(`flex),
        flexDirection(`column),
        alignContent(`flexStart),
        flexWrap(`wrap),
      ]);
    let linksContainer =
      style([
        media(
          Theme.MediaQuery.tablet,
          [display(`flex), flexDirection(`row), flexWrap(`wrap)],
        ),
      ]);
    let linksHeader =
      merge([
        Theme.Type.h4,
        style([
          marginTop(`zero),
          marginBottom(`zero),
          color(white),
          opacity(0.4),
        ]),
      ]);
    let linkStyle =
      merge([
        Theme.Type.sidebarLink,
        style([
          marginTop(`rem(0.5)),
          color(white),
          textDecoration(`none),
        ]),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.linksGrid>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader> {React.string("Get Started")} </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Documentation")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Run a Node")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Build on Mina")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Join Genesis")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Apply for Grants")}
          </a>
        </Next.Link>
      </div>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader> {React.string("Resources")} </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("About the Tech")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Knowledge Base")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Whitepapers")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Incentive Structure")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Tokenomics")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Telemetry Health Dashboard")}
          </a>
        </Next.Link>
      </div>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader> {React.string("Tools")} </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Testnet")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Block Explorers")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Node Operator Tools")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Snarketplace")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Network Health")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Network Health")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Snarkers Dashboard")}
          </a>
        </Next.Link>
      </div>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader> {React.string("Project")} </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("About Mina")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Team")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Careers")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Media")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Blog")} </a>
        </Next.Link>
      </div>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader> {React.string("Community")} </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Welcome")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle>
            {React.string("Genesis Program")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Leaderboard")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Grant Program")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Events")} </a>
        </Next.Link>
      </div>
      <div className=Styles.linksGroup>
        <h4 className=Styles.linksHeader>
          {React.string("Help and Support")}
        </h4>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Discord")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Forums")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Github")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Wiki")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Report a Bug")} </a>
        </Next.Link>
      </div>
    </div>;
  };
};

module LeftSide = {
  [@react.component]
  let make = () => {
    <div className=Styles.leftSide>
      <img
        src="/static/svg/footerLogo.svg"
        alt="Mina Logo"
        className=Styles.logo
      />
      <div className=Styles.emailInputSection>
        <div className=Styles.label> {React.string("Get Updates")} </div>
        <p className=Styles.emailSubtext>
          {React.string("Mina's growing fast! Sign up and stay in the loop.")}
        </p>
        <EmailInput />
        <div className=Styles.connectLabel> {React.string("Connect")} </div>
        <p className=Styles.emailSubtext>
          {React.string("Join the conversation.")}
        </p>
        <SocialIcons />
      </div>
    </div>;
  };
};
[@react.component]
let make = () => {
  <div className=Styles.footerContainer>
    <div className=Styles.innerContainer> <LeftSide /> <FooterLinks /> </div>
  </div>;
};
