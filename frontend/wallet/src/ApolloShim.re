// TODO: Remove this module when reason-apollo updates to support hooks

// Note: Many of these types redundantly define the option to work around a jsx3
// bug https://github.com/reasonml/reason-react/issues/369

module CreateQueryBinding = (Config: ReasonApolloTypes.Config) => {
  open ReasonApolloTypes;
  [@bs.deriving abstract]
  type renderPropObjJS = {
    loading: bool,
    data: Js.Nullable.t(Js.Json.t),
    error: Js.Nullable.t(apolloError),
    refetch: Js.Null_undefined.t(Js.Json.t) => Js.Promise.t(renderPropObjJS),
    networkStatus: Js.Nullable.t(int),
    variables: Js.Null_undefined.t(Js.Json.t),
  };
  [@bs.module "react-apollo"] [@react.component]
  external make:
    (
      ~query: queryString,
      ~variables: option(Js.Json.t)=?,
      ~pollInterval: option(int)=?,
      ~notifyOnNetworkStatusChange: option(bool)=?,
      ~fetchPolicy: option(string)=?,
      ~errorPolicy: option(string)=?,
      ~ssr: option(bool)=?,
      ~displayName: option(string)=?,
      ~skip: option(bool)=?,
      ~onCompleted: option(Js.Nullable.t(Js.Json.t) => unit)=?,
      ~onError: option(apolloError => unit)=?,
      ~partialRefetch: option(bool)=?,
      ~delay: option(bool)=?,
      ~context: option(Js.Json.t)=?,
      ~children: renderPropObjJS => ReasonReact.reactElement
    ) =>
    React.element =
    "Query";
};

module CreateQuery = (Config: ReasonApolloTypes.Config) => {
  open ReasonApolloTypes;
  module CreateQueryBinding = CreateQueryBinding(Config);
  type response = queryResponse(Config.t);
  type renderPropObj = {
    result: response,
    data: option(Config.t),
    error: option(apolloError),
    loading: bool,
    refetch: option(Js.Json.t) => Js.Promise.t(response),
    fetchMore:
      (
        ~variables: Js.Json.t=?,
        ~updateQuery: ReasonApolloQuery.updateQueryT,
        unit
      ) =>
      Js.Promise.t(unit),
    networkStatus: option(int),
    subscribeToMore:
      (
        ~document: queryString,
        ~variables: Js.Json.t=?,
        ~updateQuery: ReasonApolloQuery.updateQuerySubscriptionT=?,
        ~onError: ReasonApolloQuery.onErrorT=?,
        unit,
        unit
      ) =>
      unit,
  };
  type queryResponse('a) =
    | Loading
    | Error(apolloError)
    | Data('a);
  // TODO map over the rest of the object if we need it
  let apolloDataToVariant = (apolloData: CreateQueryBinding.renderPropObjJS) =>
    CreateQueryBinding.(
      switch (
        apolloData->loadingGet,
        apolloData->dataGet |> Js.Nullable.toOption,
        apolloData->errorGet |> Js.Nullable.toOption,
      ) {
      | (true, _, _) => Loading
      | (false, Some(response), _) => Data(Config.parse(response))
      | (false, _, Some(error)) => Error(error)
      | (false, None, None) =>
        Error({
          "message": "No data",
          "graphQLErrors": Js.Nullable.null,
          "networkError": Js.Nullable.null,
        })
      }
    );
  [@bs.module] external gql: ReasonApolloTypes.gql = "graphql-tag";
  let queryString = gql(. Config.query);
  // This component isn't really necessary but it's a helper that makes the
  // interface more similar to the old one.
  [@react.component]
  let make =
      (
        ~variables: option(Js.Json.t)=?,
        ~pollInterval: option(int)=?,
        ~notifyOnNetworkStatusChange: option(bool)=?,
        ~fetchPolicy: option(string)=?,
        ~errorPolicy: option(string)=?,
        ~ssr: option(bool)=?,
        ~displayName: option(string)=?,
        ~skip: option(bool)=?,
        ~onCompleted: option(Js.Nullable.t(Js.Json.t) => unit)=?,
        ~onError: option(apolloError => unit)=?,
        ~partialRefetch: option(bool)=?,
        ~delay: option(bool)=?,
        ~context: option(Js.Json.t)=?,
        ~children: queryResponse(Config.t) => React.element,
      ) => {
    let wrappedChildren = (objJs): React.element =>
      children(apolloDataToVariant(objJs));
    <CreateQueryBinding
      query=queryString
      variables
      pollInterval
      notifyOnNetworkStatusChange
      fetchPolicy
      errorPolicy
      ssr
      displayName
      skip
      onCompleted
      onError
      partialRefetch
      delay
      context>
      wrappedChildren
    </CreateQueryBinding>;
  };
};

module Provider = {
  [@bs.module "react-apollo"] [@react.component]
  external make:
    (~client: ApolloClient.generatedApolloClient, ~children: React.element) =>
    React.element =
    "ApolloProvider";
};
