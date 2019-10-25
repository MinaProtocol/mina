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
    ]);
  };

  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
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
let make = (~closeOnboarding, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Styles.header> {React.string("Setup Complete!")} </h1>
        <Spacer height=0.25 />
        <FadeIn duration=500 delay=150>
          <p className=Styles.heroBody>
            {React.string(
              "You've successfully set up Coda Wallet. Head over to the Faucet to request funds to start sending transactions on the Coda network.",
            )}
          </p>
        </FadeIn>
        <Spacer height=0.5 />
        <FadeIn duration=500 delay=250>
        <Link
          kind=Link.Blue
          onClick={_ => openExternal("https://discord.gg/JN75xk")}>
          {React.string("Open Discord")}
        </Link>
        </FadeIn> 
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
