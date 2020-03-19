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
    <div className=Styles.installer>
      <div className=Styles.downloader>
        <Downloader
          onFinish={result =>
            switch (result) {
            | Belt.Result.Ok(_) => setFinished(_ => true)
            | Belt.Result.Error(_) => setFinished(_ => false)
            }
          }
          finished
        />
        {finished
           ? <p className=Styles.downloaderText>
               {React.string("Installation Complete!")}
             </p>
           : <>
               <p className=Styles.installingText>
                 {React.string("Installing Coda")}
               </p>
               <a
                 onClick={_ =>
                   openExternal(
                     "https://codaprotocol.com/docs/troubleshooting",
                   )
                 }
                 target="_blank"
                 className=Styles.downloaderSubtext>
                 {React.string({j|Having problems installing Coda?|j})}
               </a>
             </>}
      </div>
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
