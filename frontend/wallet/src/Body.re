module Test = [%graphql {| query { version } |}];
module TestQuery = ApolloShim.CreateQuery(Test);

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
let make = (~message) =>
  <div
    className=Css.(style([width(`percent(100.))]))
    style={ReactDOMRe.Style.make(
      ~color="white",
      ~background="#121f2b11",
      ~fontFamily="Sans-Serif",
      ~display="flex",
      ~overflow="hidden",
      (),
    )}>
    <div
      style={ReactDOMRe.Style.make(
        ~display="flex",
        ~flexDirection="column",
        ~justifyContent="flex-start",
        ~width="20%",
        ~height="auto",
        ~overflowY="auto",
        (),
      )}>
      <WalletItem name="Hot Wallet2" balance=100.0 />
      <WalletItem name="Vault" balance=234122.123 />
    </div>
    <div
      className=Css.(style([width(`percent(100.))]))
      style={ReactDOMRe.Style.make(~margin="10px", ())}>
      <TestQuery>
        {result =>
           ReasonReact.string(
             switch (result) {
             | Loading => ""
             | Error(error) => error##message
             | Data(response) => response##version
             },
           )}
      </TestQuery>
      <HooksTest name="test-hooks" />
      <p> {ReasonReact.string(message)} </p>
      <TransactionsView />
    </div>
  </div>;
