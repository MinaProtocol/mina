module Styles = {
  open Css;
  let grid =
    style([
      display(`grid),
      padding2(~v=rem(4.), ~h=`rem(1.25)),
      gridTemplateColumns([`rem(21.)]),
      unsafe("grid-template-rows", "637px 495px 868px"),
      gridRowGap(`rem(4.)),
      backgroundSize(`cover),
      backgroundImage(url("/static/img/SecuredBySmall.png")),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(url("/static/img/SecuredByMedium.png"))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [backgroundImage(url("/static/img/SecuredByLarge.png"))],
      ),
    ]);

  let gridItem1 = style([unsafe("grid-area", "1 / 1 / 2 / 2")]);
  let gridItem2 = style([unsafe("grid-area", "2 / 1 / 3 / 2")]);
  let gridItem3 =
    style([
      marginTop(`rem(4.)),
      backgroundColor(Theme.Colors.digitalBlack),
      padding2(~v=`rem(2.), ~h=`rem(2.)),
      unsafe("grid-area", "1 / 1 / 2 / 2"),
    ]);

  let flexRow =
    style([
      display(`flex),
      width(`percent(100.)),
      flexDirection(`row),
      justifyContent(`spaceBetween),
    ]);
  let imageColumn = style([width(`rem(10.06))]);
  let logoGrid =
    style([
      display(`grid),
      gridRowGap(`rem(1.)),
      gridColumnGap(`rem(1.)),
      gridTemplateRows([`rem(5.), `rem(5.)]),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateRows([`rem(8.5), `rem(8.5)]),
          gridTemplateColumns([`rem(17.), `rem(17.)]),
        ],
      ),
    ]);
  let logo = style([height(`rem(5.))]);
  let h2 =
    merge([
      Theme.Type.h2,
      style([lineHeight(`rem(3.)), fontSize(`rem(2.5))]),
    ]);
  let h3White =
    merge([
      Theme.Type.h3,
      style([color(white), marginTop(`px(9)), marginBottom(`rem(1.))]),
    ]);
  let labelWhite =
    merge([Theme.Type.sectionSubhead, style([color(white)])]);
  let dotsImage = style([marginBottom(`rem(3.))]);
};

[@react.component]
let make = () => {
  <div className=Styles.grid>
    <div className=Styles.gridItem1>
      <Rule />
      <Spacer height=2. />
      <h2 className=Styles.h2> {React.string("Secured by Participants")} </h2>
      <Spacer height=1. />
      <p className=Theme.Type.sectionSubhead>
        {React.string(
           "The Mina network is secured by an uncapped number of block producers via inclusive proof-of-stake consensus. A uniquely decentralized blockchain, Mina gets even more secure and resilient as it grows.",
         )}
      </p>
      <Spacer height=3. />
      <div className=Styles.flexRow>
        <span className=Styles.imageColumn>
          <img src="/static/img/IllustrationBlockProducers.png" />
          <h3 className=Theme.Type.h3> {React.string("XXXX")} </h3>
          <p className=Theme.Type.label>
            {React.string("Block Producers")}
          </p>
        </span>
        <span className=Styles.imageColumn>
          <img src="/static/img/IllustrationSnarkWorkers.png" />
          <h3 className=Theme.Type.h3> {React.string("XXXX")} </h3>
          <p className=Theme.Type.label> {React.string("Snark Workers")} </p>
        </span>
      </div>
      <Spacer height=4. />
      <div className=Styles.gridItem2>
        <Rule />
        <Spacer height=2. />
        <h2 className=Styles.h2>
          {React.string("Featured Block Producers")}
        </h2>
        <Spacer height=1. />
        <p className=Theme.Type.sectionSubhead>
          {React.string(
             "Delegating is an alternative to staking Mina directly, with the benefit of not having to maintain a node that is always connected to the network. Here are some of the professional block producers offering staking services on Mina.",
           )}
        </p>
        <Spacer height=2. />
        <div className=Styles.logoGrid>
          <img className=Styles.logo src="/static/img/BisonTrailsLogo.png" />
          <img
            className=Styles.logo
            src="/static/img/FigmentNetworksLogo.png"
          />
          <img className=Styles.logo src="/static/img/NonceLogo.png" />
          <img className=Styles.logo src="/static/img/SnarkPoolLogo.png" />
        </div>
        <div className=Styles.gridItem3>
          <img
            className=Styles.dotsImage
            src="/static/img/SecuredByDots.png"
          />
          <Rule color=Theme.Colors.white />
          <h3 className=Styles.h3White>
            {React.string("You Can Run a Node & Secure the Network")}
          </h3>
          <p className=Styles.labelWhite>
            {React.string(
               "With Mina's uniquely light blockchain, you don’t have to have expensive hardware, or wait days for the blockchain to sync, or use a ton of computing power to stake and participate in consensus.",
             )}
          </p>
          <Spacer height=2. />
          <Button bgColor=Theme.Colors.orange>
            {React.string("Get Started")}
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
        </div>
      </div>
    </div>
  </div>;
};
