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
        <Button
          label="Go Back"
          style=Button.MidnightBlue
          onClick={_ => prevStep()}
        />
        <Spacer height=1.5 />
        <Button
          label="Continue"
          style=Button.HyperlinkBlue
          onClick={_ => nextStep()}
        />
      </>
    miscRight={
      <Downloader
        keyName="keys-temporary_hack-testnet_postake.tar.bz2"
        onFinish={_ => nextStep()}
      />
    }
  />;
};
