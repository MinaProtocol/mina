[@bs.scope "window"] [@bs.val]
external openExternal: string => unit = "openExternal";

type state =
  | Default
  | Checking
  | Success
  | Error(string);

module DaemonChecker = {
  module StatusQueryString = [%graphql
    {|
      query StatusQuery {
        syncStatus
      }
    |}
  ];
  module StatusQuery = ReasonApollo.CreateQuery(StatusQueryString);

  [@react.component]
  let make = (~onFinish) =>
    <StatusQuery>
      {response =>
         switch (response.result) {
         | Loading =>
           React.null
         | Error((err: ReasonApolloTypes.apolloError)) =>
           onFinish(Error(err.message));
           React.null;
         | Data(_) =>
           onFinish(Success);
           React.null;
         }}
    </StatusQuery>;
};

[@react.component]
let make = (~prevStep, ~nextStep) => {
  let (ip, setIp) = React.useState(() => "");
  let (state, setState) = React.useState(() => Default);
  let (_, setDaemonHost) = React.useContext(DaemonProvider.context);
  let handleContinue = () => {
    setDaemonHost(_ => ip);
    setState(_ => Checking);
  };

  if (state === Success) {
    nextStep();
  };

  <OnboardingTemplate
    heading="Custom Setup"
    description={
      <p>
        {React.string(
           "Where have you set up Coda? Please provide the external IP or domain. You may optionally provide a port number.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=1. />
        <TextField
          label="Host"
          placeholder="127.0.0.1"
          onChange={value => setIp(_ => value)}
          value=ip
        />
        <Spacer height=2. />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue2
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1. />
          <Button
            label="Continue"
            style=Button.HyperlinkBlue3
            disabled={ip === "" || state === Checking}
            onClick={_ => handleContinue()}
          />
        </div>
      </>
    miscRight={
      switch (state) {
      | Checking
      | Error(_) =>
        <DaemonChecker onFinish={newState => setState(_ => newState)} />
      | Default
      | Success => React.null
      }
    }
  />;
};
