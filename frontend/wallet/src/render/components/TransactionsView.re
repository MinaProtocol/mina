open Tc;

module Styles = {
  open Css;

  let container = style([height(`percent(100.))]);

  let row =
    style([
      display(`grid),
      gridTemplateColumns([`rem(16.), `fr(1.), `px(200)]),
      gridGap(Theme.Spacing.defaultSpacing),
      alignItems(`flexStart),
      padding2(~h=`rem(1.), ~v=`zero),
      borderBottom(`px(1), `solid, Theme.Colors.savilleAlpha(0.1)),
      lastChild([borderBottom(`px(0), `solid, white)]),
    ]);

  let headerRow =
    merge([
      row,
      Theme.Text.Header.h6,
      style([
        padding2(~v=`px(0), ~h=`rem(1.)),
        textTransform(`uppercase),
        height(`rem(2.)),
        alignItems(`center),
        color(Theme.Colors.slate),
        userSelect(`none),
      ]),
    ]);

  let sectionHeader =
    style([
      padding2(~v=`rem(0.25), ~h=`rem(1.)),
      textTransform(`uppercase),
      alignItems(`center),
      color(Theme.Colors.slateAlpha(0.7)),
      backgroundColor(Theme.Colors.midnightAlpha(0.06)),
      marginTop(`rem(1.5)),
    ]);

  let body =
    style([
      width(`percent(100.)),
      overflow(`auto),
      maxHeight(`calc((`sub, `percent(100.), `rem(2.)))),
    ]);

  let icon = style([opacity(0.5), height(`rem(1.5))]);

  let alertContainer =
    style([
      display(`flex),
      height(`percent(100.)),
      alignItems(`center),
      justifyContent(`center),
    ]);

  let noTransactionsAlert =
    style([
      width(`px(348)),
      height(`px(80)),
    ]);
};

module Transactions = [%graphql
  {|
    query transactions($after: String, $publicKey: String!) {
      blocks(first: 5, after: $after, filter: { relatedTo: $publicKey }) {
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
              date @bsDecoder(fn: "Apollo.Decoders.date")
            }
            feeTransfer {
              recipient @bsDecoder(fn: "Apollo.Decoders.publicKey")
              amount @bsDecoder(fn: "Apollo.Decoders.int64")
            }
            coinbase @bsDecoder(fn: "Apollo.Decoders.int64")
          }
        }
        pageInfo {
          hasNextPage
          lastCursor
        }
      }
    }
  |}
];
module TransactionsQuery = ReasonApollo.CreateQuery(Transactions);

let extractTransactions: Js.t('a) => array(TransactionCell.Transaction.t) =
  data => {
    data##blocks##nodes
    |> Array.map(~f=block => {
         open TransactionCell.Transaction;
         let userCommands =
           block##transactions##userCommands
           |> Array.map(~f=userCommand => UserCommand(userCommand));
         let blockReward =
           BlockReward({
             date: block##protocolState##blockchainState##date,
             creator: block##creator,
             coinbase: block##transactions##coinbase,
             feeTransfers: block##transactions##feeTransfer,
           });
         Array.append(userCommands, [|blockReward|]);
       })
    |> Array.concatenate;
  };

[@react.component]
let make = () => {
  let activeWallet = Hooks.useActiveWallet();
  let activeWalletKey =
    Option.map(~f=PublicKey.toString, activeWallet)
    |> Option.withDefault(~default="");
  let transactionQuery = Transactions.make(~publicKey="123", ~after="", ());
  let (isFetchingMore, setFetchingMore) = React.useState(() => false);

  let keyForTransaction = (data, index) =>
    Option.withDefault(~default="", data##blocks##pageInfo##lastCursor)
    ++ string_of_int(index);

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
        } : prevResult
    }
    |}
  ];

  <div className=Styles.container>
    <div className=Styles.headerRow>
      <span className=Css.(style([display(`flex), alignItems(`center)]))>
        {React.string("Sender")}
        <span className=Styles.icon> <Icon kind=Icon.BentArrow /> </span>
        {React.string("recipient")}
      </span>
      <span> {ReasonReact.string("Memo")} </span>
      <span className=Css.(style([textAlign(`right)]))>
        {ReasonReact.string("Date / Amount")}
      </span>
    </div>
    <TransactionsQuery variables=transactionQuery##variables>
      {response =>
         switch (response.result) {
         | Loading => <Loader.Page> <Loader /> </Loader.Page>
         | Error(err) => React.string(err##message) /* TODO format this error message */
         | Data(data) =>
           <div className=Styles.body>
             {Array.mapi(
                ~f=
                  (i, transaction) =>
                    <div
                      className=Styles.row key={keyForTransaction(data, i)}>
                      <TransactionCell transaction />
                    </div>,
                extractTransactions(data),
              )
              |> React.array}
             {!isFetchingMore
                ? <Waypoint
                    onEnter={_ => {
                      setFetchingMore(_ => true);
                      let moreTransactions =
                        Transactions.make(~publicKey=activeWalletKey, ());
                      let _ =
                        response.fetchMore(
                          ~variables=moreTransactions##variables,
                          ~updateQuery,
                          (),
                        )
                        |> Js.Promise.then_(_ => {
                             setFetchingMore(_ => false);
                             Js.Promise.resolve();
                           });
                      ();
                    }}
                    topOffset="100px"
                  />
                : <div
                    className=Css.(style([margin2(~v=`rem(1.5), ~h=`auto)]))>
                    <Loader />
                  </div>}
           </div>
         }}
    </TransactionsQuery>
  </div>;
};
