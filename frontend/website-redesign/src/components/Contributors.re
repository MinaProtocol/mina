module Styles = {
  open Css;
  let container = style([margin2(~v=`rem(4.), ~h=`zero)]);
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

  let modalContainer = modalShowing =>
    style([
      modalShowing ? opacity(1.) : opacity(0.),
      pointerEvents(`none),
      transition("opacity", ~duration=400, ~timingFunction=`easeIn),
      position(`absolute),
      height(`rem(286.8)),
      width(`vw(100.)),
      backgroundColor(`rgba((0, 0, 0, 0.3))),
      display(`flex),
      media(Theme.MediaQuery.tablet, [height(`rem(158.8))]),
      media(Theme.MediaQuery.desktop, [height(`rem(124.))]),
    ]);

  let modal = style([zIndex(100), margin(`auto)]);
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

module Modal = {
  [@react.component]
  let make = () => {
    <div className=Styles.modal>
      <GenesisMemberProfile
        key="Test Name"
        name="Test Name"
        photo="/static/img/headshots/IzaakMeckler.jpg"
        quote={"\"" ++ "This is a quote" ++ "\""}
        location="This is a location"
        twitter="twitter"
        github=None
        blogPost=None
      />
    </div>;
  };
};

[@react.component]
let make = (~profiles, ~modalOpen, ~switchModalState) => {
  <>
    <div className={Styles.modalContainer(modalOpen)}> <Modal /> </div>
    <div className=Styles.container>
      <Wrapped>
        <div className=Styles.headerCopy>
          <h2 className=Styles.header> {React.string("Meet the Team")} </h2>
          <p className=Styles.sectionSubhead>
            {React.string(
               "Mina is an inclusive open source protocol uniting teams and technicians from San Francisco and around the world.",
             )}
          </p>
        </div>
        <Rule color=Theme.Colors.black />
        <TeamGrid profiles switchModalState />
        <div className=Styles.genesisRule>
          <Rule color=Theme.Colors.black />
        </div>
        <GenesisMembersGrid />
      </Wrapped>
    </div>
  </>;
};
