module Styles = {
  open Css;
  let downloader = style([ marginLeft(`rem(2.)), display(`flex), flexDirection(`column), alignItems(`center)]);
  let downloaderText = merge([Theme.Text.Header.h3, style([color(white), width(`rem(10.))])]);
  let downloaderSubtext = merge([downloaderText, style([marginTop(`zero),width(`rem(11.)),fontSize(`px(13))])]);
}

[@react.component]
let make = (~prevStep, ~nextStep) => {
  <OnboardingTemplate
    heading="Installing Coda"
    description={
      <p>
        {React.string(
           "Coda is being installed and configured on your system.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=4. />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            label="Go Back"
            style=Button.HyperlinkBlue2
            onClick={_ => prevStep()}
          />
          <Spacer width=1.5 />
          <Button
            label="Continue"
            style=Button.HyperlinkBlue3
            onClick={_ => nextStep()}
          />
        </div>
      </>
    miscRight={
      <div className=Styles.downloader>
      <Downloader
        keyName="keys-temporary_hack-testnet_postake.tar.bz2"
        /* onFinish={_ => nextStep()} */
        onFinish = { _ => ()}
      />
      <p className=Styles.downloaderText>
        {React.string(
           "Installing Daemon",
         )}
      </p>
       <a href="https://codaprotocol.com/docs/troubleshooting" target="_blank" className=Styles.downloaderSubtext>
        {React.string({j|Coda isn't installing properly \u00A0→|j}
         )}
      </a>
      </div>
    }
  />;
};
