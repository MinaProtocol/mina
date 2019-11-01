module Styles = {
  open Css;
  let banner =
    style([
      display(`flex),
      justifyContent(`spaceAround),
      alignItems(`center),
      position(`absolute),
      top(`percent(5.0)),
      left(`calc((`sub, `percent(50.), `rem(48.0)))),
      width(`rem(96.)),
    ]);

  let logo = style([maxHeight(`rem(3.))]);

  let headerSaville =
    style([
      marginLeft(`rem(2.)),
      fontFamily(Fonts.ibmplexsans),
      fontSize(`rem(3.625)),
      color(`hex("3D5878")),
    ]);

  let headerRed = style([color(`rgb((163, 83, 111))), fontStyle(`italic)]);
};

[@react.component]
let make = (~time) => {
  <div className=Styles.banner>
    <img src="/static/img/codaLogo.png" className=Styles.logo />
    <p className=Styles.headerSaville>
      {React.string("was verified in the browser in ")}
      <span className=Styles.headerRed>
        {React.string(time ++ " milliseconds")}
      </span>
    </p>
  </div>;
};
