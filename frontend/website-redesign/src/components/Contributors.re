module Styles = {
  open Css;
  let container = style([padding2(~v=`rem(4.), ~h=`rem(1.25))]);
  let header = merge([Theme.Type.h2, style([marginBottom(`rem(0.5))])]);
  let sectionSubhead =
    merge([
      Theme.Type.sectionSubhead,
      style([
        fontSize(`rem(1.18)),
        lineHeight(`rem(1.75)),
        marginBottom(`rem(2.93)),
        letterSpacing(`pxFloat(-0.4)),
      ]),
    ]);
};

module TeamGrid = {
  module TeamMember = {
    [@react.component]
    let make = (~fullName, ~title, ~imageUrl) => {
      <div />;
    };
  };
  module Styles = {
    open Css;
    let grid =
      style([
        display(`grid),
        gridTemplateColumns([`rem(10.), `rem(10.)]),
        gridAutoRows(`rem(17.3)),
        gridColumnGap(`rem(1.)),
        gridRowGap(`rem(1.)),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.grid />;
  };
};
[@react.component]
let make = () => {
  <div className=Styles.container>
    <h2 className=Styles.header> {React.string("Meet the Team")} </h2>
    <p className=Styles.sectionSubhead>
      {React.string(
         "Mina is an inclusive open source protocol uniting teams and technicians from San Francisco and around the world.",
       )}
    </p>
    <TeamGrid />
    <Rule />
  </div>;
};
