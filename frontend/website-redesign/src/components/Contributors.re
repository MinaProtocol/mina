module Styles = {
  open Css;
  let container =
    style([
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      media(
        Theme.MediaQuery.desktop,
        [
          padding2(~v=`rem(8.), ~h=`rem(9.5)),
          maxWidth(`rem(89.)),
          margin2(~v=`zero, ~h=`auto),
        ],
      ),
    ]);
  let header = merge([Theme.Type.h2, style([marginBottom(`rem(0.5))])]);
  let sectionSubhead =
    merge([
      Theme.Type.sectionSubhead,
      style([
        fontSize(`px(19)),
        lineHeight(`rem(1.75)),
        marginBottom(`rem(2.93)),
        letterSpacing(`pxFloat(-0.4)),
      ]),
    ]);
  let headerCopy =
    style([media(Theme.MediaQuery.desktop, [width(`rem(42.))])]);
  let genesisRule =
    style([media(Theme.MediaQuery.desktop, [width(`percent(100.))])]);
};

module GenesisMembersGrid = {
  module Styles = {
    open Css;

    let genesisHeader = merge([Theme.Type.h2, style([])]);
    let genesisCopy =
      style([
        unsafe("grid-area", "1 /1 / span 1 / span 2"),
        media(Theme.MediaQuery.tablet, [width(`rem(34.))]),
      ]);
    let sectionSubhead =
      merge([
        Theme.Type.sectionSubhead,
        style([
          fontSize(`px(19)),
          lineHeight(`rem(1.75)),
          marginTop(`rem(0.5)),
          marginBottom(`rem(2.)),
          letterSpacing(`pxFloat(-0.4)),
        ]),
      ]);
    let grid =
      style([
        marginTop(`rem(1.)),
        display(`grid),
        paddingTop(`rem(1.)),
        gridTemplateColumns([`rem(10.), `rem(10.)]),
        gridAutoRows(`rem(17.3)),
        gridColumnGap(`rem(1.)),
        gridRowGap(`rem(1.)),
        media(
          Theme.MediaQuery.tablet,
          [gridTemplateColumns([`repeat((`num(3), `rem(10.)))])],
        ),
        media(
          Theme.MediaQuery.desktop,
          [gridTemplateColumns([`repeat((`num(5), `rem(11.)))])],
        ),
      ]);
  };
  [@react.component]
  let make = () => {
    <>
      <Spacer height=3. />
      <div className=Styles.genesisCopy>
        <h2 className=Styles.genesisHeader>
          {React.string("Genesis Members")}
        </h2>
        <p className=Styles.sectionSubhead>
          {React.string(
             "Meet the node operators, developers, and community builders making Mina happen.",
           )}
        </p>
      </div>
      <div className=Styles.grid>
        <TeamMember
          fullName="Greg | DeFidog"
          title="Genesis Founding Member"
          src="/static/img/headshots/Greg.jpg"
        />
        <TeamMember
          fullName="Alexander#4542"
          title="Genesis Founding Member"
          src="/static/img/headshots/Alexander.jpg"
        />
        <TeamMember
          fullName="GarethDavies"
          title="Genesis Founding Member"
          src="/static/img/headshots/GarethDavies.jpg"
        />
      </div>
    </>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <div className=Styles.headerCopy>
      <h2 className=Styles.header> {React.string("Meet the Team")} </h2>
      <p className=Styles.sectionSubhead>
        {React.string(
           "Mina is an inclusive open source protocol uniting teams and technicians from San Francisco and around the world.",
         )}
      </p>
    </div>
    <Rule color=Theme.Colors.black />
    <TeamGrid />
    <div className=Styles.genesisRule> <Rule color=Theme.Colors.black /> </div>
    <GenesisMembersGrid />
  </div>;
};
