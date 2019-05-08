let navigate = route => ReasonReact.Router.push("#" ++ Route.print(route));

[@react.component]
let make = () => 
  <div>{React.string("Hello world")}</div>;
