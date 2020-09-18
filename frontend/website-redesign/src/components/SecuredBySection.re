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
  let gridItem3 = style([unsafe("grid-area", "1 / 1 / 2 / 2")]);

  let flexRow =
    style([
      display(`flex),
      width(`percent(100.)),
      flexDirection(`row),
      justifyContent(`spaceBetween),
    ]);
  let imageColumn = style([width(`rem(10.06))]);

  let h2 =
    merge([
      Theme.Type.h2,
      style([lineHeight(`rem(3.)), fontSize(`rem(2.5))]),
    ]);
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
    </div>
  </div>;
};
