type onboardingPage =
  | Welcome
  | SetUpNode
  | CustomSetupA
  | CustomSetupB
  | CustomSetupC
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

[@react.component]
let make = () => {
  let (showOnboarding, closeOnboarding) =
    React.useContext(OnboardingProvider.context);
  let (onboardingStep, setOnboardingStep) = React.useState(() => Welcome);

  let step =
    switch (onboardingStep) {
    | Welcome =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => InstallCoda)} />
    | SetUpNode =>
      <SetupNodeStep
        customSetup={_ => setOnboardingStep(_ => CustomSetupA)}
        expressSetup={_ => setOnboardingStep(_ => InstallCoda)}
      />
    | CustomSetupA =>
      <CustomSetupA
        prevStep={_ => setOnboardingStep(_ => SetUpNode)}
        completeSetup={_ => setOnboardingStep(_ => CustomSetupB)}
      />
    | CustomSetupB =>
      <CustomSetupB
        prevStep={_ => setOnboardingStep(_ => CustomSetupA)}
        runNode={_ => setOnboardingStep(_ => RunNode)}
        nextStep={_ => setOnboardingStep(_ => CustomSetupC)}
      />
    | CustomSetupC =>
      <CustomSetupC
        prevStep={_ => setOnboardingStep(_ => CustomSetupB)}
        runNode={_ => setOnboardingStep(_ => RunNode)}
      />
    | InstallCoda =>
      <InstallCodaStep
        prevStep={_ => setOnboardingStep(_ => Welcome)}
        nextStep={_ => setOnboardingStep(_ => RunNode)}
      />
    | PortForward =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | MachineConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | CloudServerConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | RunNode =>
      <RunNodeStep
        prevStep={_ => setOnboardingStep(_ => InstallCoda)}
        createAccount={_ => setOnboardingStep(_ => AccountCreation)}
      />
    | PortForwardError =>
      <PortForwardErrorStep retry={_ => setOnboardingStep(_ => RunNode)} />
    | DaemonError =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | AccountCreation =>
      <AccountCreationStep
        prevStep={_ => setOnboardingStep(_ => RunNode)}
        nextStep={_ => setOnboardingStep(_ => StakeCoda)}
      />
    | StakeCoda =>
      <StakeCodaStep
        prevStep={_ => setOnboardingStep(_ => AccountCreation)}
        closeOnboarding
      />
    | LastStep =>
      <CompletionStep
        prevStep={_ => setOnboardingStep(_ => StakeCoda)}
        closeOnboarding
      />
    };

  showOnboarding ? step : React.null;
};
