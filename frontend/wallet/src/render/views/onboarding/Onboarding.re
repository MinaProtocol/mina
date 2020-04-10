type onboardingPage =
  | Welcome
  | SetUpNode
  | CustomSetup
  | PostCustomSetup
  | InstallCoda
  | PortForward
  | MachineConfigure
  | CloudServerConfigure
  | ConnectionStatus
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
        nextStep={_ => setOnboardingStep(_ => AccountCreation)}
      />
    | InstallCoda =>
      <InstallCodaStep
        prevStep={_ => setOnboardingStep(_ => SetUpNode)}
        nextStep={_ => setOnboardingStep(_ => AccountCreation)}
      />
    | PortForward =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | MachineConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | CloudServerConfigure =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | ConnectionStatus =>
      <ConnectionStatus
        prevStep={_ => setOnboardingStep(_ => InstallCoda)}
        createAccount={_ => setOnboardingStep(_ => LastStep)}
      />
    | PortForwardError =>
      <PortForwardErrorStep retry={_ => setOnboardingStep(_ => InstallCoda)} />
    | DaemonError =>
      <WelcomeStep nextStep={_ => setOnboardingStep(_ => SetUpNode)} />
    | AccountCreation =>
      <AccountCreationStep nextStep={_ => setOnboardingStep(_ => ConnectionStatus)} />
    | StakeCoda =>
      <StakeCodaStep
        prevStep={_ => setOnboardingStep(_ => AccountCreation)}
        closeOnboarding
      />
    | LastStep =>
      <CompletionStep
        prevStep={_ => setOnboardingStep(_ => ConnectionStatus)}
        closeOnboarding
      />
    };

  showOnboarding ? step : React.null;
};
