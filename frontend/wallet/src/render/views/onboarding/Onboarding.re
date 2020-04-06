type onboardingPage =
  | Welcome
  | SetUpNode
  | CustomSetup
  | PostCustomSetup
  | InstallCoda
  | PortForward
  | MachineConfigure
  | CloudServerConfigure
  | RunNode(bool)
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
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | SetUpNode =>
      <SetupNodeStep
        customSetup={_ => setOnboardingStep(_ => CustomSetup)}
        expressSetup={_ => setOnboardingStep(_ => InstallCoda)}
      />
    | CustomSetup =>
      <CustomSetup
        prevStep={_ => setOnboardingStep(_ => SetUpNode)}
        completeSetup={_ => setOnboardingStep(_ => PostCustomSetup)}
      />
    | PostCustomSetup =>
      <PostCustomSetup
        prevStep={_ => setOnboardingStep(_ => CustomSetup)}
        runNode={_ => setOnboardingStep(_ => RunNode(false))}
      />
    | InstallCoda =>
      <InstallCodaStep
        prevStep={_ => setOnboardingStep(_ => SetUpNode)}
        nextStep={_ => setOnboardingStep(_ => RunNode(true))}
      />
    | PortForward =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | MachineConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | CloudServerConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | RunNode(managed) =>
      <RunNodeStep
        prevStep={_ => setOnboardingStep(_ => InstallCoda)}
        createAccount={_ => setOnboardingStep(_ => AccountCreation)}
        managed
      />
    | PortForwardError =>
      <PortForwardErrorStep
        retry={_ => setOnboardingStep(_ => RunNode(true))}
      />
    | DaemonError =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | AccountCreation =>
      <AccountCreationStep
        prevStep={_ => setOnboardingStep(_ => RunNode(false))}
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
