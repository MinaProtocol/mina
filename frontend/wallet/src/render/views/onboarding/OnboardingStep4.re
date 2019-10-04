[@react.component]
let make = (~closeOnboarding, ~prevStep) => {
  <div className=Theme.Onboarding.main>
    <Button label="See My Wallet" onClick={_ => closeOnboarding()} />
    <Button label="Go back" onClick={_ => prevStep()} />
  </div>;
};
