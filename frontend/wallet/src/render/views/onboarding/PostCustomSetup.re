[@bs.scope "window"] [@bs.val]
external openExternal: string => unit = "openExternal";

[@react.component]
let make = (~prevStep, ~runNode) => {
  let (ip, setIp) = React.useState(() => "");
  let (_, setDaemonHost) = React.useContext(DaemonProvider.context);
  let handleContinue = () => {
    setDaemonHost(_ => ip);
    runNode();
  };

  <OnboardingTemplate
    heading="Custom Setup"
    description={
      <p>
        {React.string(
           "Where have you set up Coda? Please provide the external IP or domain. You may optionally provide a port number.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=1. />
        <TextField
          label="Host"
          placeholder="127.0.0.1"
          onChange={value => setIp(_ => value)}
          value=ip
        />
        <Spacer height=2. />
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
            onClick={_ => runNode()}
          />
        </div>
      </>
  />;
};
