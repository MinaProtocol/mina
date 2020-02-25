module Styles = {
  open Css;
  let downloader =
    style([
      marginLeft(`rem(2.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
    ]);
  let downloaderText =
    merge([
      Theme.Text.Header.h3,
      style([color(white), whiteSpace(`nowrap)]),
    ]);
  let downloaderSubtext =
    merge([
      downloaderText,
      style([
        textDecoration(`underline),
        marginTop(`zero),
        fontSize(`px(13)),
        hover([cursor(`pointer)]),
      ]),
    ]);
};
[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

module InstallProgress = {
  [@react.component]
  let make = (~setFinished, ~finished) =>
    <div className=Styles.downloader>
      <Downloader
        keyName="keys-temporary_hack-testnet_postake.tar.bz2"
        onFinish={_ => setFinished(_ => true)}
        finished
      />
      {finished
         ? <p className=Styles.downloaderText>
             {React.string("Installation Complete!")}
           </p>
         : <>
             <p className=Styles.downloaderText>
               {React.string("Installing Coda")}
             </p>
             <a
               onClick={_ =>
                 openExternal("https://codaprotocol.com/docs/troubleshooting")
               }
               target="_blank"
               className=Styles.downloaderSubtext>
               {React.string({j|Having problems installing Coda?|j})}
             </a>
           </>}
    </div>;
};

[@react.component]
let make = (~prevStep, ~nextStep) => {
  let (finished, setFinished) = React.useState(() => false);
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
    miscRight={<InstallProgress setFinished finished />}
  />;
};
