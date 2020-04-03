[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "openExternal";

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
          width=14.
          icon=Icon.Docs
          style=Button.OffWhite
          onClick={_ => openExternal("https://codaprotocol.com/docs/")}
        />
        <Spacer height=2.5 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue2
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1.5 />
          <Button
            width=15.
            label="Setup Is Complete"
            style=Button.HyperlinkBlue3
            onClick={_ => completeSetup()}
          />
        </div>
      </>
  />;
};
