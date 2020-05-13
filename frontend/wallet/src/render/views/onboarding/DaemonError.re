[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

external openItem: string => unit = "openItem";

[@react.component]
let make = (~tryAgain) => {
  <OnboardingTemplate
    heading="Your Node Failed To Start"
    description=
      <>
        <p>
          <b> {React.string("We do our best, but we are not perfect.")} </b>
        </p>
        <p>
          {React.string(
             "It's likely you've unconvered a bug. Please try again. If the issue persists, create a GitHub issue and a team member will be in touch.",
           )}
        </p>
      </>
    miscLeft=
      <>
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue3
            label="Try Again"
            onClick={_ => tryAgain()}
          />
          <Spacer width=1.5 />
          <Button
            label="Open Logs"
            style=Button.OffWhite
            // onClick={_ => openItem(DaemonProcess.Process.logfileName)}
          />
          <Button
            label="Create Issue"
            style=Button.OffWhite
            onClick={_ =>
              openExternal("https://github.com/CodaProtocol/coda/issues/new")
            }
          />
        </div>
      </>
  />;
};
