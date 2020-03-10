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
      maxWidth(`rem(28.0)),
      width(`percent(100.0)),
      marginLeft(`rem(5.)),
      paddingTop(`rem(7.)),
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
        marginTop(`rem(1.)),
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
    style([display(`flex), flexDirection(`row)]);
  };
};

[@react.component]
let make = (~nextStep) => {
  let mapImage = Hooks.useAsset("map@2x.png");
  <div className=Styles.main>
    <div className=Styles.map>
      <img src=mapImage alt="Map" className=Styles.map />
    </div>
    <OnboardingHeader />
    <div className=Theme.Onboarding.main>
      <div className=Styles.heroLeft>
        <FadeIn duration=500 delay=0>
          <h1 className=Styles.header> {React.string("Welcome")} </h1>
        </FadeIn>
        <FadeIn duration=500 delay=150>
          <div className=Styles.heroBody>
            <p>
              {React.string(
                 {|You're about to install everything you need to participate in Coda Protocol's revolutionary blockchain, which will make cryptocurrency accessible to everyone.|},
               )}
            </p>
          </div>
        </FadeIn>
        <div className=Styles.heroBody>
          <Button
            label="Get Started"
            style=Button.HyperlinkBlue3
            onClick={_ => nextStep()}
          />
        </div>
      </div>
    </div>
  </div>;
};
