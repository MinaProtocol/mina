open ReactIntl;
open Tc;

module Styles = {
  open Css;

  let container =
    style([height(`percent(100.)), borderLeft(`px(1), `solid, white)]);

  let headerRow =
    merge([
      Theme.Text.Header.h6,
      style([
        display(`grid),
        gridTemplateColumns([`rem(16.), `fr(1.), `px(200)]),
        gridGap(Theme.Spacing.defaultSpacing),
        padding2(~v=`px(0), ~h=`rem(1.)),
        borderBottom(`px(1), `solid, Theme.Colors.savilleAlpha(0.1)),
        borderTop(`px(1), `solid, white),
        textTransform(`uppercase),
        height(`rem(2.)),
        alignItems(`center),
        color(Theme.Colors.slate),
      ]),
    ]);

  let alertContainer =
    style([
      display(`flex),
      height(`percent(100.)),
      alignItems(`center),
      justifyContent(`center),
    ]);

  let noTransactionsAlert = style([width(`px(348)), height(`px(80))]);

  let icon = style([opacity(0.5), height(`rem(1.5))]);
};

module TransactionsQueryString = [%graphql
  {|
    query transactions($after: String, $publicKey: PublicKey!) {
      blocks(last: 5, before: $after, filter: { relatedTo: $publicKey }) {
        nodes {
          creator @bsDecoder(fn: "Apollo.Decoders.publicKey")
          protocolState {
            blockchainState {
              date @bsDecoder(fn: "Apollo.Decoders.date")
            }
          }
          transactions {
            userCommands {
              to_: to @bsDecoder(fn: "Apollo.Decoders.publicKey")
              from @bsDecoder(fn: "Apollo.Decoders.publicKey")
              amount @bsDecoder(fn: "Apollo.Decoders.int64")
              fee @bsDecoder(fn: "Apollo.Decoders.int64")
              memo
              isDelegation
            }
            feeTransfer {
              recipient @bsDecoder(fn: "Apollo.Decoders.publicKey")
              fee @bsDecoder(fn: "Apollo.Decoders.int64")
            }
            coinbase @bsDecoder(fn: "Apollo.Decoders.int64")
          }
        }
        pageInfo {
          hasNextPage
          lastCursor
        }
      }

      pooledUserCommands(publicKey: $publicKey) {
        to_: to @bsDecoder(fn: "Apollo.Decoders.publicKey")
        from @bsDecoder(fn: "Apollo.Decoders.publicKey")
        amount @bsDecoder(fn: "Apollo.Decoders.int64")
        fee @bsDecoder(fn: "Apollo.Decoders.int64")
        memo
        isDelegation
      }
    }
  |}
];
module TransactionsQuery = ReasonApollo.CreateQuery(TransactionsQueryString);

/**
  This function is getting pretty gnarly so here's an explaination.
  We take in the GraphQL response object called `data`.
  Next we extract the data from the response object, and put it into a
  record of type `{ pending: [], blocks: [] }`.
  Pending contains the pending userCommands, while transactions contains
  an array of transactions per block.
 */

type extractedResponse = {
  blocks: array(array(TransactionCell.Transaction.t)),
  pending: array(TransactionCell.Transaction.t),
};

let gqlUserCommandToRecord = ((`UserCommand userCommand), maybeDate) =>
  TransactionCell.Transaction.(
    UserCommand({
      PaymentDetails.isDelegation: userCommand##isDelegation,
      from: userCommand##from,
      to_: userCommand##to_,
      amount: userCommand##amount,
      fee: userCommand##fee,
      memo: userCommand##memo,
      date: maybeDate,
    })
  );

let extractTransactions: Js.t('a) => extractedResponse =
  data => {
    let blocks =
      data##blocks##nodes
      |> Array.map(~f=block => {
           open TransactionCell.Transaction;
           let userCommands =
             block##transactions##userCommands
             |> Array.map(~f=userCommand =>
                  gqlUserCommandToRecord(
                    userCommand,
                    Some(block##protocolState##blockchainState##date),
                  )
                );
           let blockReward =
             BlockReward({
               date: block##protocolState##blockchainState##date,
               creator: block##creator,
               coinbase: block##transactions##coinbase,
               feeTransfers: block##transactions##feeTransfer,
             });
           Array.append(userCommands, [|blockReward|]);
         });

    let pending =
      data##pooledUserCommands
      |> Array.map(~f=userCommand =>
           gqlUserCommandToRecord(userCommand, None)
         );

    {pending, blocks};
  };

[@react.component]
let make = () => {
  let activeAccount = Hooks.useActiveAccount();
  let zeroState = Hooks.useAsset("ZeroState.png");

  let updateQuery: ReasonApolloQuery.updateQueryT = [%bs.raw
    {| function (prevResult, { fetchMoreResult }) {
      const newBlocks = fetchMoreResult.blocks.nodes;
      const pageInfo = fetchMoreResult.blocks.pageInfo;
      return newBlocks.length > 0 ?
        {
          blocks: {
            __typename: "BlockConnection",
            nodes: [...prevResult.blocks.nodes, ...newBlocks],
            pageInfo,
          },
          // Since these aren't paginated, we can just reuse the previous result
          pooledUserCommands: prevResult.pooledUserCommands,
        } : prevResult
    }
    |}
  ];

  <div className=Styles.container>
    {switch (activeAccount) {
     | Some(pubkey) =>
       let variables =
         Js.Dict.fromList([
           ("publicKey", Apollo.Encoders.publicKey(pubkey)),
           ("after", Js.Json.null),
         ])
         |> Js.Json.object_;
       <TransactionsQuery variables fetchPolicy="network-only">
         (
           response =>
             switch (response.result) {
             | Loading => <Loader.Page> <Loader /> </Loader.Page>
             | Error((err: ReasonApolloTypes.apolloError)) =>
               React.string(err.message) /* TODO format this error message */
             | Data(data) =>
               let {blocks, pending} = extractTransactions(data);
               let transactions = Array.concatenate(blocks);
               let lastCursor =
                 Option.withDefault(
                   ~default="",
                   data##blocks##pageInfo##lastCursor,
                 );
               <BlockListener
                 refetch={() =>
                   response.refetch(Some(variables))
                 }
                 subscribeToMore={response.subscribeToMore}>
                 <div className=Styles.headerRow>
                   <span
                     className=Css.(
                       style([display(`flex), alignItems(`center)])
                     )>
                     <FormattedMessage id="sender" defaultMessage="sender" />
                     <span className=Styles.icon>
                       <Icon kind=Icon.BentArrow />
                     </span>
                     <FormattedMessage
                       id="recipient"
                       defaultMessage="recipient"
                     />
                   </span>
                   <span>
                     <FormattedMessage id="memo" defaultMessage="memo" />
                   </span>
                   <span className=Css.(style([textAlign(`right)]))>
                     <FormattedMessage
                       id="transactions.date/amount"
                       defaultMessage="date / amount"
                     />
                   </span>
                 </div>
                 {switch (Array.length(transactions), Array.length(pending)) {
                  | (0, 0) =>
                    <div className=Styles.alertContainer>
                      <Alert
                        kind=`Info
                        defaultMessage="You don't have any transactions related to this account."
                      />
                    </div>
                  | (_, _) =>
                    <TransactionsList
                      pending
                      transactions
                      hasNextPage=data##blocks##pageInfo##hasNextPage
                      onLoadMore={() => {
                        let moreTransactions =
                          TransactionsQueryString.make(
                            ~publicKey=Apollo.Encoders.publicKey(pubkey),
                            ~after=lastCursor,
                            (),
                          );

                        response.fetchMore(
                          ~variables=Some(moreTransactions##variables),
                          ~updateQuery,
                          (),
                        );
                      }}
                    />
                  }}
               </BlockListener>;
             }
         )
       </TransactionsQuery>;
     | None =>
       <div className=Styles.alertContainer>
         <img
           width="608px"
           src=zeroState
           alt="Join the revolution on Discord"
         />
       </div>
     }}
  </div>;
};
