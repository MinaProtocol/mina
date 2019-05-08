module Test = [%graphql {| query { version } |}];
module TestQuery = ReasonApollo.CreateQuery(Test);

module HooksTest = {
  [@react.component]
  let make = (~name) => {
    let (count, setCount) = React.useState(() => 0);

    <div>
      <p>
        {React.string(
           name ++ " clicked " ++ string_of_int(count) ++ " times",
         )}
      </p>
      <button onClick={_ => setCount(count => count + 1)}>
        {React.string("Click me")}
      </button>
    </div>;
  };
};

[@react.component]
let make = (~message, ~settingsOrError, ~setSettingsOrError) =>
  switch (settingsOrError) {
  | Belt.Result.Error(_) =>
    <div>
      <p>
        {ReasonReact.string("There was an error loading the settings!")}
      </p>
      <p> {ReasonReact.string(message)} </p>
    </div>
  | Belt.Result.Ok(settings) =>
    <div
      className=Css.(
        style([
          display(`flex),
          overflow(`hidden),
          width(`percent(100.)),
          color(Css.white),
          backgroundColor(Theme.Colors.bgWithAlpha),
        ])
      )>
      <div
        className=Css.(
          style([
            display(`flex),
            flexDirection(`column),
            justifyContent(`flexStart),
            width(`rem(24.)),
            borderRight(`px(1), `solid, white),
            height(`auto),
            overflowY(`auto),
          ])
        )>
        <WalletList settings setSettingsOrError />
      </div>
      <div
        className=Css.(style([width(`percent(100.)), margin(`rem(1.25))]))>
        <TestQuery>
          (
            response =>
              ReasonReact.string(
                switch (response.result) {
                | Loading => "..."
                | Error(error) => error##message
                | Data(response) => response##version
                },
              )
          )
        </TestQuery>
        <HooksTest name="test-hooks" />
        <p> {ReasonReact.string(message)} </p>
        <TransactionsView />
      </div>
    </div>
  };
