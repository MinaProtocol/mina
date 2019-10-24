module Styles = {
  open Css;

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);

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

  let header = {
    merge([
      Theme.Text.Header.h1,
      //style([animation(fadeIn, ~duration=1000, ~iterationCount=`count(1))]),
    ]);
  };

  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
        opacity(0.),
        maxWidth(`rem(21.5)),
        color(Theme.Colors.midnightBlue),
        animation(fadeIn, ~duration=500, ~iterationCount=`count(1)),
        animationDelay(250),
        animationFillMode(`forwards),
      ]),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~closeOnboarding, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Styles.header> {React.string("Setup Complete!")} </h1>
        <Spacer height=1. />
        <p className=Styles.heroBody>
          {React.string(
             "You've successfully set up Coda Wallet. Head over to the Faucet to request funds to start sending transactions on the Coda network.",
           )}
        </p>
        <Spacer height=0.5 />
        <Link
          kind=Link.Blue
          onClick={_ => openExternal("https://discord.gg/JN75xk")}>
          {React.string("Open Discord")}
        </Link>
        <Spacer height=2. />
        <div className=Styles.buttonRow>
          <Button
            style=Button.Gray
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
          <Button label="Continue" onClick={_ => closeOnboarding()} />
        </div>
      </div>
      <div
        // Graphic goes here
      />
    </div>
  </div>;
};
