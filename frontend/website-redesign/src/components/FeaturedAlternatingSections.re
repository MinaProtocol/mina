module Styles = {
  open Css;

  let container = style([border(`px(1), `solid, red)]);

  let sectionBackgroundImage =
    style([
      height(`rem(120.)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      backgroundImage(
        `url("/static/img/FeaturedAlternatingSectionsBackground.png"),
      ),
      media(Theme.MediaQuery.tablet, [height(`rem(190.))]),
      media(Theme.MediaQuery.desktop, [height(`rem(230.))]),
    ]);

  let rowContainer = (~reverse=false, ()) =>
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      marginTop(`rem(2.)),
      media(
        Theme.MediaQuery.tablet,
        [
          reverse ? flexDirection(`rowReverse) : flexDirection(`row),
          marginTop(`rem(6.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          reverse ? flexDirection(`rowReverse) : flexDirection(`row),
          marginTop(`rem(12.5)),
        ],
      ),
    ]);

  let textContainer = style([maxWidth(`rem(29.)), width(`percent(100.))]);

  let seperator = seperatorNumber =>
    style([
      display(`flex),
      alignItems(`center),
      borderBottom(`px(1), `solid, Theme.Colors.digitalBlack),
      before([
        contentRule(seperatorNumber),
        color(Theme.Colors.digitalBlack),
      ]),
    ]);

  let title = style([marginTop(`rem(1.5))]);

  let paragraphText = style([marginTop(`rem(1.5))]);

  let linkText =
    style([marginTop(`rem(1.5)), display(`flex), alignItems(`center)]);

  let image =
    style([width(`percent(100.)), height(`auto), maxWidth(`rem(29.))]);
};

[@react.component]
let make = () => {
  <div className=Styles.sectionBackgroundImage>
    <Wrapped>
      <div className={Styles.rowContainer()}>
        <div className=Styles.textContainer>
          <div className={Styles.seperator("01")} />
          <h2 className=Styles.title>
            {React.string("Easily Accessible, Now & Always")}
          </h2>
          <p className=Styles.paragraphText>
            {React.string(
               "Other protocols are so heavy they require intermediaries to run nodes, recreating the same old power dynamics. But Mina is light, so anyone can connect peer-to-peer and sync and verify the chain in seconds. Built on a consistent-sized cryptographic proof, the blockchain will stay accessible - even as it scales to millions of users.",
             )}
          </p>
          <span className=Styles.linkText>
            <span> {React.string("Explore the Tech")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </div>
        <img src="/static/hands.png" className=Styles.image />
      </div>
      <div className={Styles.rowContainer(~reverse=true, ())}>
        <div className=Styles.textContainer>
          <div className={Styles.seperator("02")} />
          <h2 className=Styles.title>
            {React.string(
               "Truly Decentralized, with Full Nodes like Never Before",
             )}
          </h2>
          <p className=Styles.paragraphText>
            {React.string(
               "With Mina, anyone who’s syncing the chain is also validating transactions like a full node. Mina’s design means any participant can take part in proof-of-stake consensus, have access to strong censorship-resistance and secure the blockchain.",
             )}
          </p>
          <span className=Styles.linkText>
            <span> {React.string("Run a node")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </div>
        <img src="/static/spread.png" />
      </div>
      <div className={Styles.rowContainer()}>
        <div className=Styles.textContainer>
          <div className={Styles.seperator("03")} />
          <h2 className=Styles.title>
            {React.string("Light Chain, High Speed")}
          </h2>
          <p className=Styles.paragraphText>
            {React.string(
               "Other protocols are weighed down by terabytes of private user data and network congestion. But on Mina’s 22kb chain, apps execute as fast as your bandwidth can carry them — paving the way for a seamless end user experience and mainstream adoption.",
             )}
          </p>
          <span className=Styles.linkText>
            <span> {React.string("Explore the Tech")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </div>
        <img src="/static/shooting_star.png" />
      </div>
      <div className={Styles.rowContainer(~reverse=true, ())}>
        <div className=Styles.textContainer>
          <div className={Styles.seperator("04")} />
          <h2 className=Styles.title>
            {React.string("Private & Powerful Apps, Thanks to Snapps")}
          </h2>
          <p className=Styles.paragraphText>
            {React.string(
               "Mina enables an entirely new category of applications — Snapps. These SNARK-powered decentralized apps are optimized for efficiency, privacy and scalability. Logic and data are computed off-chain, then verified on-chain by the end user’s device. And information is validated without disclosing specifics, so people stay in control of their personal data.",
             )}
          </p>
          <span className=Styles.linkText>
            <span> {React.string("Build on Mina")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </div>
        <img src="/static/parts.png" />
      </div>
      <div className={Styles.rowContainer()}>
        <div className=Styles.textContainer>
          <div className={Styles.seperator("05")} />
          <h2 className=Styles.title>
            {React.string("Programmable Money, For All")}
          </h2>
          <p className=Styles.paragraphText>
            {React.string(
               "Mina’s peer-to-peer permissionless network empowers participants to build and interact with tokens directly — without going through a centralized wallet, exchange or intermediary. And payments can be made in Mina’s native asset, stablecoin or in user-generated programmable tokens — opening a real world of possibilities.",
             )}
          </p>
          <span className=Styles.linkText>
            <span> {React.string("Build on Mina")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </span>
        </div>
        <img src="/static/door.png" />
      </div>
    </Wrapped>
  </div>;
};
