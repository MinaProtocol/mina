open Tc;

module CreateQuery = (Config: ReasonApolloTypes.Config) => {
  module ReasonApolloInternal = ReasonApolloQuery.Make(Config);
  let query = instance => {
    Task.liftPromise(() =>
      instance##query({
        "query": ReasonApolloInternal.graphqlQueryAST,
        "variables": Js.Json.array([||]),
      })
    )
    |> Task.map(~f=v => ReasonApolloInternal.convertJsInputToReason(v));
  };
};
