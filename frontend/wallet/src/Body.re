let component = ReasonReact.statelessComponent("Body");

module Test = [%graphql {| query { greeting } |}];
module TestQuery = ReasonApollo.CreateQuery(Test);

let make = (~message as _, _children) => {
  ...component,
  render: _self => {
    <div
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
          <WalletItem name="Hot Wallet" balance=100.0 />
          <WalletItem name="Vault" balance=234122.123 />
        </div>
        <div style={ReactDOMRe.Style.make(~margin="10px", ())}>
          <TestQuery>
            ...{({result}) =>
              ReasonReact.string(
                switch (result) {
                | Loading => ""
                | Error(error) => error##message
                | Data(response) => response##greeting
                },
              )
            }
          </TestQuery>
        </div>
      </div>;
      // </div>
  },
};
