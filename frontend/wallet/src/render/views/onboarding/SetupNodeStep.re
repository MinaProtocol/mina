open Tc;

module Styles = {
  open Css;
  let map = WelcomeStep.Styles.map;
  let hero = style([display(`flex), width(`percent(100.))]);
  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);
  let heroLeft =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(28.0)),
      marginLeft(`px(80)),
    ]);

  let heroRight =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      width(`percent(100.)),
      color(Theme.Colors.slateAlpha(0.4)),
    ]);
  let header = {
    WelcomeStep.Styles.header;
  };
  let heroBody = WelcomeStep.Styles.heroBody;

  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

module NetworkQueryString = [%graphql {|
    {
      initialPeers
    }
  |}];

module NetworkQuery = ReasonApollo.CreateQuery(NetworkQueryString);

type daemonState =
  | Loading
  | Started
  | Unavailable;

[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~customSetup, ~expressSetup) => {
  let mapImage = Hooks.useAsset("map@2x.png");
  <div className=Theme.Onboarding.main>
    <div className=Styles.map> <img src=mapImage alt="Map" /> </div>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <FadeIn duration=500>
          <h1 className=Styles.header>
            {React.string("Setting Up Your Node")}
          </h1>
        </FadeIn>
        <FadeIn duration=500 delay=150>
          <p className=Styles.heroBody>
            {React.string(
               "Your node will allow you to connect to the Coda network and make transactions.",
             )}
          </p>
        </FadeIn>
        <Spacer height=2.0 />
        <div className=Styles.buttonRow>
          <Button
            style=Button.MidnightBlue
            label="Custom Setup"
            onClick={_ => customSetup()}
          />
          <Spacer width=0.5 />
          <Button
            label="Express Setup"
            style=Button.HyperlinkBlue
            onClick={_ => expressSetup()}
          />
        </div>
      </div>
    </div>
  </div>;
};
