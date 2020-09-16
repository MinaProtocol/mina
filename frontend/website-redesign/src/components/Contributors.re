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

 module TeamMember = {
    module Styles = {
          open Css;
          let memberContainer = style([height(`rem(17.)), width(`rem(11.)), color(orange)]);
          let image = style([height(`rem(10.5))]);
          let name = merge([Theme.Type.h5, style([lineHeight(`rem(1.37)), color(black), fontSize(`px(18))])]);
          let title = merge([Theme.Type.contributorLabel, style([lineHeight(`rem(1.37)), color(black),fontSize(`px(18))])]);

      };
    [@react.component]
    let make = (~fullName="", ~title="", ~src="") => {
      <div className=Styles.memberContainer> 
        <img className=Styles.image src=src/>
        <> <h5 className=Styles.name> {React.string(fullName)}</h5> <Icon kind=Icon.Plus/> </>
        <p className=Styles.title> {React.string(title)}</p>
      </div>;
    };
  };

module TeamGrid = {
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
    <div className=Styles.grid> 
        <TeamMember fullName="Evan Shapiro" title="CEO, O(1) Labs" src="/static/img/headshots/EvanShapiro.jpg"/>
    </div>
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
