[@react.component]
let make = (~prevStep, ~runNode, ~nextStep) => {
  <OnboardingTemplate
    heading="Custom Setup"
    description={<p> {React.string("Where is your node located?")} </p>}
    miscLeft=
      <>
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.MidnightBlue
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
          <Button
            label="Local Machine"
            style=Button.HyperlinkBlue
            onClick={_ => runNode()}
          />
          <Spacer width=0.5 />
          <Button
            label="Remote Server"
            style=Button.HyperlinkBlue
            onClick={_ => nextStep()}
          />
        </div>
      </>
  />;
};
