let component = ReasonReact.statelessComponent("Body");

let handleClick = (_event, _self) => Js.log("clicked!");

module Test = [%graphql {| { greeting } |}];
module TestQuery = ReasonApollo.CreateQuery(Test);

let make = (~message as _, _children) => {
  ...component,
  render: self => {
    <div
      style={ReactDOMRe.Style.make(
        ~color="white",
        ~fontFamily="Sans-Serif",
        ~padding="15px",
        (),
      )}>
      <div onClick={self.ReasonReact.handle(handleClick)}>
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
  },
};
