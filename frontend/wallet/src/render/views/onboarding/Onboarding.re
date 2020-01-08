type onboardingPage =
  | Welcome
  | SetUpNode
  | InstallCoda
  | PortForward
  | MachineConfigure
  | CloudServerConfigure
  | RunNode
  | PortForwardError
  | DaemonError
  | AccountCreation
  | StakeCoda
  | LastStep;

module Styles = {
  open Css;

  let main =
    style([
      position(`absolute),
      top(`zero),
      left(`zero),
      display(`flex),
      flexDirection(`row),
      paddingTop(Theme.Spacing.headerHeight),
      paddingBottom(Theme.Spacing.footerHeight),
      height(`vh(100.)),
      width(`vw(100.)),
      zIndex(100),
    ]);
  let fadeIn = keyframes([(0, [opacity(0.)]), (100, [opacity(1.)])]);
  let body =
    merge([
      Theme.Text.Body.regular,
      style([animation(fadeIn, ~duration=1050, ~iterationCount=`count(1))]),
    ]);
  let map =
    style([
      position(`fixed),
      left(`px(0)),
      top(`px(0)),
      zIndex(1),
      maxWidth(`percent(100.)),
    ]);
};

[@react.component]
let make = () => {
  let (showOnboarding, closeOnboarding) =
    React.useContext(OnboardingProvider.context);
  let (onboardingStep, setOnboardingStep) = React.useState(() => Welcome);

  let step =
    switch (onboardingStep) {
    | Welcome =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | SetUpNode =>
      <SetupNodeStep
        customSetup={_ => setOnboardingStep(_ => InstallCoda)}
        expressSetup={_ => setOnboardingStep(_ => InstallCoda)}
      />
    | InstallCoda =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | PortForward =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | MachineConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | CloudServerConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | RunNode =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | PortForwardError =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | DaemonError =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | AccountCreation =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | StakeCoda =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | LastStep => <CompletionStep closeOnboarding />
    };

  let mapImage = Hooks.useAsset("map@2x.png");

  showOnboarding
    ? <div className=Styles.main>
        <div className=Styles.map>
          <img src=mapImage alt="Map" className=Styles.map />
        </div>
        <OnboardingHeader />
        step
      </div>
    : React.null;
};
