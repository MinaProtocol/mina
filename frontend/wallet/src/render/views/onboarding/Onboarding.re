module Styles = {
  open Css;

  let main =
    style([
      position(`absolute),
      top(`zero),
      left(`zero),
      background(white),
      zIndex(100),
      display(`flex),
      flexDirection(`row),
      paddingTop(Theme.Spacing.headerHeight),
      paddingBottom(Theme.Spacing.footerHeight),
      height(`vh(100.)),
      width(`vw(100.)),
    ]);
  let fadeIn = keyframes([(0, [opacity(0.)]), (100, [opacity(1.)])]);
  let body =
    merge([
      Theme.Text.Body.regular,
      style([animation(fadeIn, ~duration=1050, ~iterationCount=`count(1))]),
    ]);
};

let onboardingSteps = [
  <p className=Styles.body> {React.string("Step 1")} </p>,
  <p className=Styles.body> {React.string("Step 2")} </p>,
];

[@react.component]
let make = () => {
  let (showOnboarding, closeOnboarding) =
    React.useContext(OnboardingProvider.context);
  let (onboardingStep, setOnboardingStep) = React.useState(() => 0);
  let prevStep = () =>
    if (onboardingStep > 0) {
      setOnboardingStep(currentStep => currentStep - 1);
    };

  let nextStep = () =>
    if (onboardingStep >= List.length(onboardingSteps) - 1) {
      closeOnboarding();
    } else {
      setOnboardingStep(currentStep => currentStep + 1);
    };

  showOnboarding
    ? <div className=Styles.main>
        <Header />
        {Array.of_list(onboardingSteps)[onboardingStep]}
        <Button label="Continue" onClick={_ => nextStep()} />
        <Button label="Previous Step" onClick={_ => prevStep()} />
      </div>
    : React.null;
};
