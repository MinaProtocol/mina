[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~prevStep, ~nextStep) => {
  <OnboardingTemplate
    heading="Stake Coda to Earn Rewards"
    description={
      <p>
        {React.string(
           "Enable automatic staking on your account once you receive your first Coda tokens.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.MidnightBlue
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1.5 />
          <Button
            width=17.
            style=Button.MidnightBlue
            label="Continue without Auto-Staking"
            onClick={_ => nextStep()}
          />
          <Spacer width=1.5 />
          <Button
            width=13.
            label="Enable Auto-Staking"
            style=Button.HyperlinkBlue
            onClick={_ => nextStep()}
          />
        </div>
      </>
  />;
};
