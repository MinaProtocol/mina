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
            style=Button.HyperlinkBlue2
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1.0 />
          <Button
            label="Local Machine"
            style=Button.HyperlinkBlue3
            onClick={_ => runNode()}
          />
          <Spacer width=1.5 />
          <Button
            label="Remote Server"
            style=Button.HyperlinkBlue3
            onClick={_ => nextStep()}
          />
        </div>
      </>
  />;
};
