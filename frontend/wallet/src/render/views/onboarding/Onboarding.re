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
      zIndex(-1),
      maxWidth(`percent(100.)),
    ]);
};

[@react.component]
let make = () => {
  let (showOnboarding, closeOnboarding) =
    React.useContext(OnboardingProvider.context);
  let (onboardingStep, setOnboardingStep) = React.useState(() => 0);
  let prevStep = () => {
    setOnboardingStep(currentStep => currentStep - 1);
  };

  let nextStep = () => {
    setOnboardingStep(currentStep => currentStep + 1);
  };

  let onboardingSteps = [
    <WelcomeStep nextStep />,
    <SetupNodeStep nextStep prevStep />,
    <AccountCreationStep nextStep prevStep />,
    <CompletionStep closeOnboarding prevStep />,
  ];

  let mapImage = Hooks.useAsset("map@2x.png");

  showOnboarding
    ? <div className=Styles.main>
        <div className=Styles.map>
          <img src=mapImage alt="Map" className=Styles.map />
        </div>
        <OnboardingHeader />
        {Array.of_list(onboardingSteps)[onboardingStep]}
      </div>
    : React.null;
};
