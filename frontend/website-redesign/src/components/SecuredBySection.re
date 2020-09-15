module Styles = {
  open Css;
  let grid =
    style([
      display(`grid),
      backgroundSize(`cover),
      backgroundImage(url("/static/img/SecuredBySmall.png")),
      padding2(~v=rem(4.), ~h=`rem(1.25)),
      gridTemplateColumns([`rem(21.)]),
      gridTemplateRows([`rem(40.), `rem(31.), `rem(54.)]),
      gridRowGap(`rem(4.)),
      media(
        Theme.MediaQuery.tablet,
        [
          padding2(~v=rem(4.5), ~h=`rem(2.5)),
          gridTemplateColumns([`rem(43.)]),
          gridTemplateRows([`rem(30.), `rem(18.06), `rem(35.)]),
          gridRowGap(`rem(4.)),
          backgroundImage(url("/static/img/SecuredByMedium.png")),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          padding2(~v=rem(8.9), ~h=`rem(9.56)),
          gridTemplateColumns([`rem(31.5), `rem(29.)]),
          gridTemplateRows([`rem(31.5), `rem(32.)]),
          gridColumnGap(`rem(6.8)),
          gridRowGap(`rem(6.)),
          backgroundImage(url("/static/img/SecuredByLarge.png")),
        ],
      ),
    ]);

  let gridItem1 = style([unsafe("grid-area", "1 / 1 / 2 / 2")]);
  let gridItem2 = style([unsafe("grid-area", "2 / 1 / 3 / 2")]);
  let gridItem3 =
    style([
      backgroundColor(Theme.Colors.digitalBlack),
      padding2(~v=`rem(2.), ~h=`rem(2.)),
      unsafe("grid-area", "3/1"),
      media(
        Theme.MediaQuery.tablet,
        [display(`flex), flexDirection(`row), unsafe("grid-area", "3/1")],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          unsafe("grid-area", "1 / 2 / 3 / 3"),
          flexDirection(`column),
          padding2(~v=`rem(4.), ~h=`rem(3.5)),
        ],
      ),
    ]);
  // This is the third dark background grid item
  let textColumn =
    style([
      media(
        Theme.MediaQuery.tablet,
        [display(`flex), flexDirection(`column), marginLeft(`rem(3.))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [marginTop(`rem(2.)), marginLeft(`zero)],
      ),
    ]);
  let flexRow =
    style([
      display(`flex),
      width(`percent(100.)),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      media(Theme.MediaQuery.tablet, [width(`rem(30.))]),
    ]);
  let imageColumn =
    style([
      width(`rem(10.)),
      media(Theme.MediaQuery.tablet, [width(`rem(13.))]),
    ]);
  let logoGrid =
    style([
      display(`grid),
      gridRowGap(`rem(1.)),
      gridColumnGap(`rem(1.)),
      gridTemplateRows([`rem(5.), `rem(5.)]),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateRows([`rem(5.)]),
          gridTemplateColumns([
            `rem(10.),
            `rem(10.),
            `rem(10.),
            `rem(10.),
          ]),
          marginBottom(`rem(4.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateRows([`rem(8.5), `rem(8.5)]),
          gridTemplateColumns([`rem(17.), `rem(17.)]),
          marginBottom(`zero),
        ],
      ),
    ]);
  let logo = style([height(`rem(5.))]);
  let h2 =
    merge([
      Theme.Type.h2,
      style([lineHeight(`rem(3.0)), fontSize(`rem(2.5))]),
    ]);
  let h2Small =
    merge([
      Theme.Type.h2,
      style([
        important(lineHeight(`rem(1.5))),
        important(fontSize(`rem(2.))),
      ]),
    ]);

  let h3White =
    merge([
      Theme.Type.h3,
      style([color(white), marginTop(`px(9)), marginBottom(`rem(1.))]),
    ]);
  let labelWhite =
    merge([Theme.Type.sectionSubhead, style([color(white)])]);
  let dotsImage =
    style([
      marginBottom(`rem(3.)),
      media(Theme.MediaQuery.tablet, [marginRight(`rem(3.))]),
      media(
        Theme.MediaQuery.desktop,
        [marginRight(`zero), marginBottom(`zero), height(`rem(35.6))],
      ),
    ]);
  let button = style([media(Theme.MediaQuery.tablet, [])]);
};
[@react.component]
let make = () => {
  <div className=Styles.grid>
    <div className=Styles.gridItem1>
      <Rule />
      <Spacer height=1. />
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
    </div>
    <Spacer height=4. />
    <div className=Styles.gridItem2>
      <Rule />
      <Spacer height=2. />
      <h2 className=Styles.h2Small>
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
        <img className=Styles.logo src="/static/img/FigmentNetworksLogo.png" />
        <img className=Styles.logo src="/static/img/NonceLogo.png" />
        <img className=Styles.logo src="/static/img/SnarkPoolLogo.png" />
      </div>
    </div>
    <div className=Styles.gridItem3>
      <img className=Styles.dotsImage src="/static/img/SecuredByDots.png" />
      <Rule color=Theme.Colors.white />
      <span className=Styles.textColumn>
        <h3 className=Styles.h3White>
          {React.string("You Can Run a Node & Secure the Network")}
        </h3>
        <p className=Styles.labelWhite>
          {React.string(
             "With Mina's uniquely light blockchain, you don't have to have expensive hardware, or wait days for the blockchain to sync, or use a ton of computing power to stake and participate in consensus.",
           )}
        </p>
        <Spacer height=2. />
        <span className=Styles.button>
          <Button bgColor=Theme.Colors.orange>
            {React.string("Get Started")}
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
        </span>
      </span>
    </div>
  </div>;
};
