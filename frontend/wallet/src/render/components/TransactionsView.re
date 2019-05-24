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
      marginLeft(`rem(0.25)),
      padding2(~h=`rem(0.75), ~v=`zero),
      borderBottom(`px(1), `solid, Theme.Colors.savilleAlpha(0.1)),
      lastChild([borderBottom(`px(0), `solid, white)]),
    ]);

  let headerRow =
    style([
      padding2(~v=`px(0), ~h=`rem(1.)),
      textTransform(`uppercase),
      height(`rem(2.)),
      alignItems(`center),
      color(Theme.Colors.slateAlpha(1.)),
    ]);

  let body =
    style([
      width(`percent(100.)),
      overflow(`auto),
      maxHeight(`calc((`sub, `percent(100.), `rem(2.)))),
    ]);
};

module Transactions = [%graphql
  {|
    query transactions($publicKey: String!) {
      blocks(filter: { relatedTo: $publicKey }) {
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
      }
    }
  |}
];
module TransactionsQuery = ReasonApollo.CreateQuery(Transactions);

let extractTransactions: Js.t('a) => array(TransactionCell.Transaction.t) = data => {
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
     }) |> Array.concatenate;
};

[@react.component]
let make = () => {
  let transactionQuery = Transactions.make(~publicKey="123", ());
  <div className=Styles.container>
    <div
      className={Css.merge([
        Styles.row,
        Theme.Text.smallHeader,
        Styles.headerRow,
      ])}>
      <span> {ReasonReact.string("Sender")} </span>
      <span> {ReasonReact.string("Memo")} </span>
      <span className=Css.(style([textAlign(`right)]))>
        {ReasonReact.string("Transaction")}
      </span>
    </div>
    <TransactionsQuery variables=transactionQuery##variables>
      {response =>
         switch (response.result) {
         | Loading => React.string("...") /* TODO replace with a spinner */
         | Error(err) => React.string(err##message) /* TODO format this error message */
         | Data(data) =>
           <div className=Styles.body>
             {Array.map(
                ~f=
                  transaction =>
                    <div className=Styles.row>
                      <TransactionCell transaction />
                    </div>,
                extractTransactions(data),
              )
              |> React.array}
           </div>
         }}
    </TransactionsQuery>
  </div>;
};
