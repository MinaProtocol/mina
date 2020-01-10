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
        <Button
          label="Go Back"
          style=Button.MidnightBlue
          onClick={_ => prevStep()}
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
