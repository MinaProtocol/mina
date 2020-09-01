module Styles = {
  open Css;
  let footerContainer =
    style([
      left(`zero),
      bottom(`zero),
      height(`rem(106.)),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      backgroundImage(`url("/static/img/Small.png")),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.tablet,
        [
          padding2(~v=`rem(4.), ~h=`rem(2.68)),
          height(`rem(75.)),
          backgroundImage(`url("/static/img/Medium.png")),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          padding2(~v=`rem(5.5), ~h=`rem(9.5)),
          height(`rem(48.)),
          backgroundImage(`url("/static/img/Large.png")),
        ],
      ),
    ]);
  let backToTopButtonContent =
    style([
      display(`flex),
      height(`rem(2.62)),
      flexDirection(`column),
      alignContent(`center),
      justifyContent(`spaceBetween),
      color(white),
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
      style([color(white), marginTop(`zero), marginBottom(`rem(1.))]),
    ]);
  let backToTopButton =
    style([position(`absolute), right(`rem(1.)), bottom(`rem(2.))]);
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
        gridColumnGap(`rem(0.5)),
        gridRowGap(`rem(3.1)),
        marginTop(`rem(4.)),
        media(
          Theme.MediaQuery.tablet,
          [
            marginTop(`rem(5.8)),
            gridRowGap(`rem(3.)),
            gridColumnGap(`rem(5.)),
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
    let linksHeader =
      merge([
        Theme.Type.footerHeaderLink,
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

module Subfooter = {
  module Styles = {
    open Css;
    let column =
      style([
        display(`flex),
        flexDirection(`column),
        width(`rem(21.)),
        height(`rem(14.4)),
        media(Theme.MediaQuery.tablet, [height(`rem(3.75))]),
        media(
          Theme.MediaQuery.desktop,
          [
            justifyContent(`spaceBetween),
            width(`rem(71.)),
            height(`rem(1.4)),
            marginTop(`rem(1.5)),
            flexDirection(`rowReverse),
          ],
        ),
      ]);
    let smallLinks =
      merge([
        Theme.Type.navLink,
        style([
          fontSize(`px(14)),
          color(white),
          textDecoration(`none),
          marginTop(`rem(1.5)),
          media(Theme.MediaQuery.desktop, [marginTop(`zero)]),
        ]),
      ]);
    let linksContainer =
      style([
        display(`flex),
        flexDirection(`column),
        media(
          Theme.MediaQuery.tablet,
          [
            flexDirection(`row),
            justifyContent(`spaceBetween),
            alignContent(`center),
            width(`rem(36.5)),
          ],
        ),
      ]);
    let copyright =
      merge([
        Theme.Type.paragraphSmall,
        style([
          color(white),
          margin2(~v=`rem(1.5), ~h=`zero),
          opacity(0.6),
          media(Theme.MediaQuery.tablet, [marginBottom(`rem(0.))]),
          media(Theme.MediaQuery.desktop, [margin2(~v=`zero, ~h=`zero)]),
        ]),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.column>
      <div className=Styles.linksContainer>
        <Next.Link href="">
          <a className=Styles.smallLinks>
            {React.string("Mina Foundation")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.smallLinks> {React.string("O(1) Labs")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.smallLinks>
            {React.string("Code of Conduct")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.smallLinks>
            {React.string("Privacy Policy")}
          </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.smallLinks>
            {React.string("Terms of Service")}
          </a>
        </Next.Link>
      </div>
      <p className=Styles.copyright>
        {React.string({js|©|js} ++ "2020 Mina. Started by O(1) Labs.")}
      </p>
    </div>;
  };
};

module WhiteLine = {
  module Styles = {
    open Css;
    let whiteLine =
      style([
        border(`px(1), `solid, white),
        marginTop(`rem(3.0)),
        width(`percent(100.)),
        opacity(0.2),
        marginBottom(`rem(0.)),
      ]);
  };
  [@react.component]
  let make = () => {
    <hr className=Styles.whiteLine />;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.footerContainer>
    <div className=Styles.innerContainer> <LeftSide /> <FooterLinks /> </div>
    <WhiteLine />
    <Subfooter />
    <Button
      height={`rem(4.125)}
      width={`rem(3.75)}
      bgColor=Theme.Colors.black
      borderColor=Theme.Colors.white
      paddingX=1.1
      paddingY=0.75
      dark=true>
      <span className=Styles.backToTopButtonContent>
        <Icon kind=Icon.ArrowUpMedium size=1. />
        {React.string("Top")}
      </span>
    </Button>
  </div>;
};
