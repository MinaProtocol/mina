[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "openExternal";

[@react.component]
let make = (~prevStep, ~runNode) => {
  let (ip, setIp) = React.useState(() => "123.43.234.23");
  let (_, setDaemonHost) = React.useContext(DaemonProvider.context);

  let handleContinue = () => {
    setDaemonHost(_ => ip);
    runNode()
  };

  <OnboardingTemplate
    heading="Custom Setup"
    description={<p> {React.string("Where have you set up Coda?")} </p>}
    miscLeft=
      <>
        <Spacer height=2.5 />
        <TextField
          label="IP Address"
          onChange={value => setIp(_ => value)}
          value=ip
        />
        <Spacer height=2.5 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue2
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1. />
          <Button
            label="Continue"
            style=Button.HyperlinkBlue3
            onClick={_ => handleContinue()}
          />
        </div>
      </>
  />;
};
