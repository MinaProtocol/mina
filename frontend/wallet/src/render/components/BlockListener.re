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
        children
    };
};

[@react.component]
let make = (~children, ~response: Transactions.TransactionsQuery.renderPropObj) => 
    <SubscriptionWrapper subscribeToMore={() => 
        response.subscribeToMore(
            ~document=newBlockAst,
            ~updateQuery=
                (prev, _) => {
                    response.refetch(None) |> ignore;
                    prev
                },
                (),
            );
        }
    >
        {children}
    </SubscriptionWrapper>;
