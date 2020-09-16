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

[@react.component]
let make = () => {
  <div className=Styles.container>
    <h2 className=Styles.header> {React.string("Meet the Team")} </h2>
    <p className=Styles.sectionSubhead>
      {React.string(
         "Mina is an inclusive open source protocol uniting teams and technicians from San Francisco and around the world.",
       )}
    </p>
    <Rule />
  </div>;
};
