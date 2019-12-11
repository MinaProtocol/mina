[@bs.module "graphql-tag"] external gql: ReasonApolloTypes.gql = "default";

module NewBlock = [%graphql
  {|
      subscription newBlock {
        newBlock {
          stateHash
        }
      }
    |}
];

let newBlock = NewBlock.make();
let newBlockAst = gql(. newBlock##query);

module SubscriptionWrapper = {
  [@react.component]
  let make = (~children, ~subscribeToMore) => {
    let _ =
      React.useEffect0(() => {
        subscribeToMore();
        None;
      });
    children;
  };
};

[@react.component]
let make =
    (
      ~children,
      ~subscribeToMore:
         (
           ~document: ReasonApolloTypes.queryString,
           ~variables: Js.Json.t=?,
           ~updateQuery: ReasonApolloQuery.updateQuerySubscriptionT=?,
           ~onError: ReasonApolloQuery.onErrorT=?,
           unit
         ) =>
         unit,
      ~refetch,
    ) =>
  <SubscriptionWrapper
    subscribeToMore={() =>
      subscribeToMore(
        ~document=newBlockAst,
        ~updateQuery=
          (prev, _) => {
            refetch() |> ignore;
            prev;
          },
        (),
      )
    }>
    children
  </SubscriptionWrapper>;
