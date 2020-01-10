[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~prevStep, ~completeSetup) => {
  <OnboardingTemplate
    heading="Custom Setup"
    description={
      <p>
        {React.string(
           "Our technical documentation should provide you with everything needed to install Coda. ",
         )}
      </p>
    }
    miscLeft=
      <>
        <Button
          label="Coda Install Guide"
          icon=Icon.Docs
          style=Button.OffWhite
          onClick={_ => openExternal("https://codaprotocol.com/docs/")}
        />
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.MidnightBlue
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
          <Button
            label="Setup Is Complete"
            style=Button.HyperlinkBlue
            onClick={_ => completeSetup()}
          />
        </div>
      </>
  />;
};
