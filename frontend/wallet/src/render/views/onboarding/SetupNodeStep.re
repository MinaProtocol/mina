[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "openExternal";

[@react.component]
let make = (~customSetup, ~expressSetup) => {
  <OnboardingTemplate
    heading="Setting Up Your Node"
    description={
      <p>
        {React.string(
           "Your node will allow you to connect to the Coda Network and make transactions.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue2
            label="Custom Setup"
            onClick={_ => customSetup()}
          />
          <Spacer width=1.5 />
          <Button
            label="Express Setup"
            style=Button.HyperlinkBlue3
            onClick={_ => expressSetup()}
          />
        </div>
      </>
  />;
};
