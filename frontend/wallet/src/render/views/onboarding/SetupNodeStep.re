module Styles = {
  open Css;

  let hero = style([display(`flex), width(`percent(100.))]);

  let heroLeft =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(28.0)),
      marginLeft(`px(80)),
    ]);

  let heroRight =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
      width(`percent(100.)),
      color(Theme.Colors.slateAlpha(0.4)),
    ]);

  let heroBody =
    merge([
      Theme.Text.Body.regular,
      style([
        marginTop(`rem(2.)),
        marginBottom(`rem(2.)),
        maxWidth(`rem(24.)),
        color(Theme.Colors.midnightBlue),
      ]),
    ]);

  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

module NetworkQueryString = [%graphql {|
    {
      initialPeers
    }
  |}];

module NetworkQuery = ReasonApollo.CreateQuery(NetworkQueryString);

type daemonState =
  | Loading
  | Started
  | Unavailable;

[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "";

[@react.component]
let make = (~nextStep, ~prevStep) => {
  let dispatchToMain = React.useContext(ProcessDispatchProvider.context);
  let (state, setState) = React.useState(() => Unavailable);
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Theme.Text.Header.h1>
          {React.string("Setting Up Your Node")}
        </h1>
        <p className=Styles.heroBody>
          {React.string(
             "First, let's install and configure the Coda daemon. This will allow you to connect to the Coda network and make transactions. Follow the instructions at the link below to begin.",
           )}
        </p>
        <Link
          kind=Link.Blue
          onClick={_ =>
            openExternal("https://codaprotocol.com/docs/getting-started/")
          }>
          {React.string("Getting started")}
        </Link>
        <Spacer height=2.0 />
        <div className=Styles.buttonRow>
          <Button
            style=Button.Gray
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
          <Button
            label="Continue"
            onClick={_ => {
              dispatchToMain(
                CodaProcess.Action.StartCoda([
                  "-peer",
                  "filet-mignon.o1test.net:8303",
                ]),
              );
              setState(_ => Loading);
            }}
          />
        </div>
      </div>
      <div className=Styles.heroRight>
        {switch (state) {
         | Loading =>
           <NetworkQuery>
             (
               ({result}) =>
                 switch (result) {
                 | Data(_) =>
                   nextStep();
                   React.null;
                 | _ =>
                   <>
                     <Loader hideText=true />
                     <p className=Theme.Text.Body.regular>
                       {React.string("Starting your node...")}
                     </p>
                   </>
                 }
             )
           </NetworkQuery>
         | Started =>
           nextStep();
           React.null;
         | Unavailable => React.null
         }}
      </div>
    </div>
  </div>;
};
