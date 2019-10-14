module Styles = {
  open Css;

  let map =
    style([
      position(`fixed),
      left(`px(0)),
      top(`px(0)),
      zIndex(-1),
      maxWidth(`percent(100.)),
    ]);

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(32.0)),
      marginLeft(`px(80)),
    ]);
  };

  let heroBody = {
    merge([
      Theme.Text.Body.regular,
      style([
        marginTop(`rem(2.)),
        marginBottom(`rem(3.)),
        maxWidth(`rem(28.)),
        color(Theme.Colors.midnightBlue),
      ]),
    ]);
  };
};

[@react.component]
let make = (~nextStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.map>
      <img src="map@2x.png" alt="Map" className=Styles.map />
    </div>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Theme.Text.Header.h1>
          {React.string("Welcome to Coda Wallet!")}
        </h1>
        <p className=Styles.heroBody>
          {React.string(
             {|Coda swaps the traditional blockchain for a tiny cryptographic proof, enabling a cryptocurrency that stays the same size forever. With the Coda Wallet you can send, recieve and view transactions on the Coda network.|},
           )}
        </p>
        <div> <Button label="Continue" onClick={_ => nextStep()} /> </div>
      </div>
      <div
        // Graphic goes here
      />
    </div>
  </div>;
};
