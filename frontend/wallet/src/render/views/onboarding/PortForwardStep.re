[@react.component]
let make = (~nextStep) => {
  <OnboardingTemplate
    heading="Configure Port Forwarding"
    description={
      <p>
        {React.string(
           {|You're about to install everything you need to participate in Coda Protocol's revolutionary blockchain, which will make cryptocurrency accessible to everyone.|},
         )}
      </p>
    }
    miscLeft={
      <Button
        label="Get Started"
        style=Button.HyperlinkBlue3
        onClick={_ => nextStep()}
      />
    }
  />;
};
