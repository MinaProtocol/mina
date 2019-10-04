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

[@react.component]
let make = (~closeOnboarding, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Theme.Text.Header.h1>
          {React.string("Coda Wallet Setup Complete!")}
        </h1>
        <p className=Styles.heroBody>
          {React.string(
             "You've successfully set up Coda Wallet. Head over to the Faucet to request funds to start sending transactions on the Coda network.",
           )}
        </p>
        <Spacer height=1.0 />
        <div className=Styles.buttonRow>
          <Button label="Go Back" onClick={_ => prevStep()} />
          <Spacer width=0.5 />
          <Button label="See My Wallet" onClick={_ => closeOnboarding()} />
        </div>
      </div>
      <div
        // Graphic goes here
      />
    </div>
  </div>;
};
