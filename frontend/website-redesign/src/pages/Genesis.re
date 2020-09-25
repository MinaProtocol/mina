module Styles = {
  open Css;
  let genesisSection =
    style([
      backgroundImage(`url("/static/img/GenesisMiddleBackground.png")),
      backgroundSize(`cover),
    ]);
};

module HowItWorksGrid = {
  module Styles = {
    open Css;
    let container =
      style([
        display(`flex),
        flexDirection(`column),
        media(
          Theme.MediaQuery.desktop,
          [flexDirection(`row), justifyContent(`spaceBetween)],
        ),
      ]);
    let grid =
      style([
        display(`grid),
        gridTemplateColumns([`rem(21.)]),
        gridAutoRows(`rem(15.43)),
        gridRowGap(`rem(1.)),
        marginTop(`rem(2.)),
        marginBottom(`rem(4.)),
        media(
          Theme.MediaQuery.tablet,
          [
            gridTemplateColumns([`rem(21.), `rem(21.)]),
            gridColumnGap(`rem(1.)),
          ],
        ),
        media(Theme.MediaQuery.desktop, [marginTop(`zero)]),
      ]);
    let h2 = merge([Theme.Type.h2, style([color(white)])]);
    let h4 = merge([Theme.Type.h4, style([fontWeight(`normal)])]);
    let gridItem = style([backgroundColor(white), padding(`rem(1.5))]);
    let link = merge([Theme.Type.link, style([textDecoration(`none)])]);
  };

  module GridItem = {
    [@react.component]
    let make = (~label="", ~children=?) => {
      <div className=Styles.gridItem>
        <h4 className=Styles.h4> {React.string(label)} </h4>
        <Spacer height=1. />
        {switch (children) {
         | Some(children) => children
         | None => <> </>
         }}
      </div>;
    };
  };

  [@react.component]
  let make = () => {
    <div className=Styles.container>
      <h2 className=Styles.h2> {React.string("How It Works")} </h2>
      <div className=Styles.grid>
        <GridItem label="What Members Do: Pre-Mainnet">
          <p className=Theme.Type.paragraph>
            {React.string(
               "Get hands-on experience developing applications with zero knowledge proofs, plus an overview of different types of constructions.",
             )}
          </p>
        </GridItem>
        <GridItem label="What Members Do: Post-Mainnet">
          <p className=Theme.Type.paragraph>
            {React.string(
               "Participate as block producers by continuously staking or delegating their Mina tokens — plus everything they were doing pre-mainnet. ",
             )}
          </p>
        </GridItem>
        <GridItem label="Who is Selected">
          <p className=Theme.Type.paragraph>
            {React.string(
               "Highly engaged node operators and community leaders, with new Genesis Members being announced on a rolling basis until we reach a thousand.",
             )}
          </p>
        </GridItem>
        <GridItem label="What They Get">
          <p className=Theme.Type.paragraph>
            {React.string(
               "To ensure decentralization, Mina has allocated 6.6% of the protocol (or 66,000 Mina tokens) to Genesis Founding Members.",
             )}
          </p>
          // TODO: Add link here to terms and conditions
          <Next.Link href="/">
            <a className=Styles.link>
              {React.string("Read Terms and Conditions.")}
            </a>
          </Next.Link>
        </GridItem>
      </div>
    </div>;
  };
};

module FoundingMembersSection = {
  module Styles = {
    open Css;
    let container =
      style([
        padding2(~v=`rem(4.), ~h=`rem(0.)),
        backgroundImage(`url("/static/img/GenesisMiddleBackground.png")),
        backgroundSize(`cover),
      ]);
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
  };
  [@react.component]
  let make = () => {
    <div className=Styles.container>
      <Wrapped>
        <h2 className=Styles.h2>
          {React.string("Genesis Founding Members")}
        </h2>
        <p className=Styles.sectionSubhead>
          {React.string(
             "Get to know some of the founding members working to strengthen the protocol and build our community.",
           )}
        </p>
      </Wrapped>
    </div>;
  };
};

module CultureFooter = {
  module Styles = {
    open Css;
    let container = style([padding2(~v=`rem(2.5), ~h=`rem(2.5))]);
    let grid =
      style([
        display(`grid),
        gridTemplateColumns([`rem(12.93), `rem(47.)]),
        gridColumnGap(`rem(2.56)),
      ]);
  };
  [@react.component]
  let make = () => {
    
  }
};

[@react.component]
let make = () => {
  <Page title="Genesis Page">
    <Hero
      title="Community"
      header="Genesis Program"
      copy="We're looking for community members to join the Genesis Token Grant Program and form the backbone of Mina's robust decentralized network."
      backgroundSmall="/static/img/GenesisSmall.jpg"
      backgroundMedium="/static/img/GenesisMedium.jpg"
      backgroundLarge="/static/img/GenesisLarge.jpg">
      <Spacer height=2. />
      <Button bgColor=Theme.Colors.black>
        {React.string("Apply Now")}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </Hero>
    <FeaturedSingleRow
      row={
        FeaturedSingleRow.Row.rowType: ImageLeftCopyRight,
        title: "Become a Genesis Member",
        description: "Up to 1,000 community participants will be selected to help us harden Mina’s protocol, strengthen the network and receive a distribution of 66,000 tokens.",
        textColor: Theme.Colors.white,
        image: "/static/img/GenesisCopy.jpg",
        background: Image("/static/img/BecomeAGenesisMemberBackground.png"),
        contentBackground: Image("/static/img/BecomeAGenesisMember.jpg"),
        button: {
          FeaturedSingleRow.Row.buttonText: "Apply Now",
          buttonColor: Theme.Colors.orange,
          buttonTextColor: Theme.Colors.white,
          dark: false,
          href: "/",
        },
      }>
      <Spacer height=4. />
      <Rule color=Theme.Colors.white />
      <Spacer height=4. />
      <HowItWorksGrid />
      <Rule color=Theme.Colors.white />
      <Spacer height=7. />
    </FeaturedSingleRow>
    <div className=Styles.genesisSection>
      <FoundingMembersSection />
      <WorldMapSection />
      <Spacer height=4. />
      <CultureFooter />
    </div>
  </Page>;
};
