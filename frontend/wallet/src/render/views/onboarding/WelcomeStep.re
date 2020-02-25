[@react.component]
let make = (~nextStep) => {
  <OnboardingTemplate
    heading="Welcome"
    description={
      <span className={Css.style([Css.maxWidth(`rem(28.))])}>
        <p>
          {React.string(
             {|You're about to install everything you need to participate in Coda Protocol's revolutionary blockchain, which will make cryptocurrency accessible to everyone.|},
           )}
        </p>
      </span>
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
