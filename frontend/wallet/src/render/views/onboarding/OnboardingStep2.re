module Styles = {
  open Css;

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(28.0)),
      marginLeft(`px(80)),
    ]);
  };

  let heroBody = {
    style([
      marginTop(`rem(2.)),
      marginBottom(`rem(3.)),
      maxWidth(`rem(21.5)),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

[@react.component]
let make = (~nextStep, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1> {React.string("Setting Up Your Node")} </h1>
        <p className=Styles.heroBody>
          {React.string(
             "First, let's set up the Coda daemon. This will allow you to connect to the Coda network and make transactions. Click on Get Started to begin.",
           )}
        </p>
        <div className=Styles.buttonRow>
          <Button label="Go Back" onClick={_ => prevStep()} />
          <Spacer width=0.5 />
          <Button label="Continue" onClick={_ => nextStep()} />
        </div>
      </div>
      <div
        // Graphic goes here
      />
    </div>
  </div>;
};
