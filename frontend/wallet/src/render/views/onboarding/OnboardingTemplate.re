module Styles = {
  open Css;
  let hero = {
    style([display(`flex), flexDirection(`row), paddingTop(`rem(5.))]);
  };
  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      width(`percent(100.0)),
      maxWidth(`rem(22.5)),
      marginLeft(`rem(5.)),
      paddingTop(`rem(6.)),
    ]);
  };
  let heroRight = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      paddingTop(`rem(7.)),
    ]);
  };
  let header = {
    merge([Theme.Text.title, style([color(white)])]);
  };
  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
        maxWidth(`rem(23.125)),
        color(white),
        animationFillMode(`forwards),
      ]),
    ]);
  };

  let main =
    style([
      position(`absolute),
      top(`zero),
      left(`zero),
      display(`flex),
      flexDirection(`row),
      paddingTop(`rem(7.5)),
      height(`vh(100.)),
      width(`vw(100.)),
      zIndex(100),
    ]);
  let map =
    style([
      position(`fixed),
      left(`px(0)),
      top(`px(0)),
      zIndex(1),
      maxWidth(`percent(100.)),
    ]);
  let buttonRow = {
    style([
      width(`percent(100.)),
      display(`flex),
      flexDirection(`row),
      selector("button", [flexGrow(1.)]),
    ]);
  };
};

[@react.component]
let make = (~heading, ~description, ~miscLeft, ~miscRight=?) => {
  let mapImage = Hooks.useAsset("map@2x.png");
  <div className=Styles.main>
    <div className=Styles.map>
      <img src=mapImage alt="Map" className=Styles.map />
    </div>
    <OnboardingHeader />
    <div className=Theme.Onboarding.main>
      <div className=Styles.heroLeft>
        <FadeIn duration=500 delay=0>
          <h1 className=Styles.header> {React.string(heading)} </h1>
        </FadeIn>
        <FadeIn duration=500 delay=150>
          <div className=Styles.heroBody> description </div>
        </FadeIn>
        <div className=Styles.heroBody> miscLeft </div>
      </div>
      {switch (miscRight) {
       | Some(items) =>
         <>
           <Spacer width=10.0 />
           <div className=Styles.heroRight> items </div>
         </>
       | None => React.null
       }}
    </div>
  </div>;
};
