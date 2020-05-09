[@bs.scope "window"] [@bs.val]
external openExternal: string => unit = "openExternal";

module Styles = {
  open Css;
  let loader = style([display(`flex), justifyContent(`center)]);

  let elapsedTime =
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
  let smallText =
    merge([
      downloaderText,
      style([
        marginTop(`zero),
        fontSize(`px(13)),
        hover([cursor(`pointer)]),
      ]),
    ]);
};

module StatusQueryString = [%graphql
  {|
    query StatusQuery {
      syncStatus
    }
  |}
];
module StatusQuery = ReasonApollo.CreateQuery(StatusQueryString);

[@react.component]
let make = (~prevStep as _, ~nextStep, ~errorStep as _) => {
  // Start the daemon process if we're in managed setup
  let dispatch = React.useContext(ProcessDispatchProvider.context);
  CodaProcess.useStartEffect(Some(dispatch));

  <StatusQuery>
    {response =>
       <OnboardingTemplate
         heading="Connecting to the Network"
         description={
           <p>
             {React.string(
                "Establishing a connection typically takes between 5-15 minutes.",
              )}
           </p>
         }
         miscLeft=
           <>
             <Spacer height=2.0 />
             <div className=OnboardingTemplate.Styles.buttonRow>
               <Spacer width=12. />
               <Button
                 label="Continue"
                 disabled={
                   switch (response.result) {
                   | Data(_) => false
                   | _ => true
                   }
                 }
                 style=Button.HyperlinkBlue3
                 onClick={_ => nextStep()}
               />
             </div>
           </>
         miscRight={
           <div className=Styles.loader>
             <div className=Styles.elapsedTime>
               {switch (response.result) {
                | Loading =>
                  <>
                    <LoaderRing />
                    <Spacer height=1.25 />
                    <p className=Styles.smallText>
                      {React.string("Connecting to the network...")}
                    </p>
                  </>
                | Error(_) =>
                  <>
                    <Downloader.ErrorIcon />
                    <Spacer height=1.25 />
                    <p className=Styles.smallText>
                      {React.string("Unable to connect to daemon")}
                    </p>
                  </>
                | Data(_) =>
                  <>
                    <Downloader.SuccessIcon />
                    <Spacer height=1.25 />
                    <p className=Styles.smallText>
                      {React.string("Successfully synced!")}
                    </p>
                  </>
                }}
             </div>
           </div>
         }
       />}
  </StatusQuery>;
};
