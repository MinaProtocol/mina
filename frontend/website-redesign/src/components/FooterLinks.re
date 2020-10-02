module Styles = {
  open Css;
  let linksGrid =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(2), `fr(1.)))]),
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
          gridTemplateRows([`repeat((`num(2), `rem(15.1)))]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [marginTop(`rem(0.)), height(`rem(30.))],
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
      style([marginTop(`rem(0.5)), color(white), textDecoration(`none)]),
    ]);
};

// TODO: Add links to footer
[@react.component]
let make = () => {
  <div className=Styles.linksGrid>
    <div className=Styles.linksGroup>
      <h4 className=Styles.linksHeader> {React.string("Get Started")} </h4>
      <Next.Link href="/docs/getting-started">
        <a className=Styles.linkStyle> {React.string("Documentation")} </a>
      </Next.Link>
      <Next.Link href="/docs/node-operator">
        <a className=Styles.linkStyle> {React.string("Run a Node")} </a>
      </Next.Link>
      <Next.Link href="/tech">
        <a className=Styles.linkStyle> {React.string("Build on Mina")} </a>
      </Next.Link>
      <Next.Link href="/genesis">
        <a className=Styles.linkStyle> {React.string("Join Genesis")} </a>
      </Next.Link>
      <Next.Link
        href="https://github.com/MinaProtocol/mina-grants#how-to-apply">
        <a className=Styles.linkStyle> {React.string("Apply for Grants")} </a>
      </Next.Link>
    </div>
    <div className=Styles.linksGroup>
      <h4 className=Styles.linksHeader> {React.string("Resources")} </h4>
      <Next.Link href="/tech">
        <a className=Styles.linkStyle> {React.string("About the Tech")} </a>
      </Next.Link>
      <Next.Link href="">
        <a className=Styles.linkStyle> {React.string("Knowledge Base")} </a>
      </Next.Link>
      <Next.Link
        href="/blog/mina-protocol-the-worlds-lightest-blockchain-releases-its-economics">
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
    </div>
    <div
      className=Css.(
        style([
          display(`none),
          media(Theme.MediaQuery.tablet, [display(`block)]),
        ])
      )
    />
    <div className=Styles.linksGroup>
      <h4 className=Styles.linksHeader> {React.string("Community")} </h4>
      <Next.Link href="/about">
        <a className=Styles.linkStyle> {React.string("Welcome")} </a>
      </Next.Link>
      <Next.Link href="/genesis">
        <a className=Styles.linkStyle> {React.string("Genesis Program")} </a>
      </Next.Link>
      <Next.Link href="/leaderboard">
        <a className=Styles.linkStyle> {React.string("Leaderboard")} </a>
      </Next.Link>
      <Next.Link href="https://github.com/MinaProtocol/mina-grants">
        <a className=Styles.linkStyle> {React.string("Grant Program")} </a>
      </Next.Link>
    </div>
    <div className=Styles.linksGroup>
      <h4 className=Styles.linksHeader>
        {React.string("Help and Support")}
      </h4>
      <Next.Link href="https://discord.com/invite/Vexf4ED">
        <a className=Styles.linkStyle> {React.string("Discord")} </a>
      </Next.Link>
      <Next.Link href="https://forums.minaprotocol.com/">
        <a className=Styles.linkStyle> {React.string("Forums")} </a>
      </Next.Link>
      <Next.Link href="https://github.com/MinaProtocol/mina">
        <a className=Styles.linkStyle> {React.string("Github")} </a>
      </Next.Link>
      <Next.Link href="https://minawiki.com/Main_Page">
        <a className=Styles.linkStyle> {React.string("Wiki")} </a>
      </Next.Link>
      <Next.Link href="https://github.com/MinaProtocol/mina/issues">
        <a className=Styles.linkStyle> {React.string("Report a Bug")} </a>
      </Next.Link>
    </div>
    <div />
  </div>;
};
