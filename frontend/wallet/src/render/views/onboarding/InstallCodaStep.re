module Styles = {
  open Css;
  let installer = style([display(`flex), justifyContent(`center)]);
  let downloader =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      width(`rem(12.)),
    ]);
  let downloaderText =
    merge([
      Theme.Text.Header.h3,
      style([color(white), whiteSpace(`nowrap)]),
    ]);
  let installingText =
    merge([
      Theme.Text.Header.h3,
      style([color(white), whiteSpace(`nowrap)]),
    ]);
  let downloaderSubtext =
    merge([downloaderText, style([marginTop(`zero), fontSize(`px(13))])]);
  let downloaderLink =
    merge([
      downloaderSubtext,
      style([textDecoration(`underline), hover([cursor(`pointer)])]),
    ]);
};
[@bs.scope "window"] [@bs.val]
external openExternal: string => unit = "openExternal";

type state =
  | Init
  | Downloading
  | Error(string)
  | Finished;

module InstallProgress = {
  [@react.component]
  let make = (~setState, ~installerState) =>
    <div className=Styles.installer>
      <div className=Styles.downloader>
        <Downloader
          onFinish={result =>
            switch (result) {
            | Belt.Result.Ok(_) =>
              Js.log("Install complete...");
              Bindings.LocalStorage.setItem(~key=`Installed, ~value="true");
              setState(_ => Finished);
            | Belt.Result.Error(err) => setState(_ => Error(err))
            }
          }
          finished={installerState === Finished}
          error={
            switch (installerState) {
            | Error(_) => true
            | _ => false
            }
          }
        />
        {switch (installerState) {
         | Finished =>
           <p className=Styles.downloaderText>
             {React.string("Installation Complete!")}
           </p>
         | Error(err) =>
           <>
             <p className=Styles.installingText>
               {React.string("Installation Error")}
             </p>
             <p className=Styles.downloaderSubtext> {React.string(err)} </p>
           </>
         | _ =>
           <>
             <p className=Styles.installingText>
               {React.string("Installing Coda")}
             </p>
             <a
               onClick={_ =>
                 openExternal("https://codaprotocol.com/docs/troubleshooting")
               }
               target="_blank"
               className=Styles.downloaderLink>
               {React.string({j|Having problems installing Coda?|j})}
             </a>
           </>
         }}
      </div>
    </div>;
};

[@react.component]
let make = (~prevStep, ~nextStep) => {
  let (installerState, setInstallerState) = React.useState(() => Init);

  <OnboardingTemplate
    heading="Installing Coda"
    description={
      <p>
        {React.string(
           "Coda is being installed and configured on your system. This should take 1-2 min depending on your internet speed.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=2. />
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
            disabled={
              switch (installerState) {
              | Finished => false
              | _ => true
              }
            }
          />
        </div>
      </>
    miscRight={<InstallProgress setState=setInstallerState installerState />}
  />;
};
