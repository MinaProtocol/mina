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
    merge([
      Theme.Text.Body.regular,
      style([
        marginTop(`rem(2.)),
        marginBottom(`rem(3.)),
        maxWidth(`rem(21.5)),
        color(Theme.Colors.midnightBlue),
      ]),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~nextStep, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Theme.Text.Header.h1>
          {React.string("Setting Up Your Node")}
        </h1>
        <p className=Styles.heroBody>
          {React.string(
             "First, let's set up the Coda daemon. This will allow you to connect to the Coda network and make transactions. Click on Get Started to begin.",
           )}
        </p>
        <Link
          kind=Link.Blue
          onClick={_ =>
            openExternal("https://codaprotocol.com/docs/getting-started/")
          }>
          {React.string("View the Docs")}
        </Link>
        <Spacer height=1.0 />
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
