let str = ReasonReact.string;

let component = ReasonReact.statelessComponent("RunScript");

let make = children => {
  ...component,
  render: _self =>
    <script
      dangerouslySetInnerHTML={
        "__html":
          switch (children) {
          | [|code|] => code
          | _ => failwith("RunScript used without a script")
          },
      }
    />,
};
