[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~retry) => {
  <OnboardingTemplate
    heading="Your Node Is Not Discoverable"
    description=
      <>
        <p> {React.string("Ports have not been forwarded correctly.")} </p>
        <p>
          {React.string("Please double check your networking configuration.")}
        </p>
      </>
    miscLeft=
      <>
        <Button
          width=15.5
          label="Port Forwarding Help"
          style=Button.OffWhite
          onClick={_ =>
            openExternal("https://codaprotocol.com/docs/troubleshooting/")
          }
        />
        <Spacer height=3. />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            label="Retry"
            style=Button.HyperlinkBlue2
            onClick={_ => retry()}
          />
          <Button
            label="I've Fixed the Problem"
            style=Button.HyperlinkBlue3
            onClick={_ => retry()}
          />
        </div>
      </>
  />;
};
