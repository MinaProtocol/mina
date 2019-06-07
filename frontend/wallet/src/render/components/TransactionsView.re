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
    style([
      padding2(~v=`px(0), ~h=`rem(1.)),
      textTransform(`uppercase),
      height(`rem(2.)),
      alignItems(`center),
      color(Theme.Colors.slate),
      userSelect(`none),
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
  let transactionQuery = Transactions.make(~publicKey="123", ());
  let emptyTransactionsView = 
    <div className=Styles.alertContainer>
      <div className=Styles.noTransactionsAlert>
        <Alert
          kind=`Info
          message={|
            Your Coda wallet is empty. Once you receive 
            Coda, your transactions will appear here.
          |}
        />
      </div>
    </div>;
  <div className=Styles.container>
    <TransactionsQuery variables=transactionQuery##variables>
      {response =>
        switch (response.result) {
        | Loading => <Loader.Page><Loader /></Loader.Page>
        | Error(err) => React.string(err##message) /* TODO format this error message */
        | Data(data) =>
          let transactions = extractTransactions(data);
          switch (Array.length(transactions)) {
          | 0 => emptyTransactionsView 
          | _ =>
            <>  
              <div
                className={Css.merge([
                  Styles.row,
                  Theme.Text.Header.h6,
                  Styles.headerRow,
                ])}
              >
                <span className=Css.(style([display(`flex), alignItems(`center)]))>
                  {React.string("Sender")}
                  <span className=Styles.icon> <Icon kind=Icon.BentArrow /> </span>
                  {React.string("Recipient")}
                </span>
                <span>
                  {ReasonReact.string("Memo")}
                </span>
                <span className=Css.(style([textAlign(`right)]))>
                  {ReasonReact.string("Date / Amount")}
                </span>
              </div>
              <div className=Styles.body>
                {Array.map(
                  ~f=
                    transaction =>
                      /* TODO(PM): Add unique key here for transaction */
                      <div className=Styles.row>
                        <TransactionCell transaction />
                      </div>,
                  transactions,
                )
                |> React.array}
              </div>
            </>
          }
        }
      }
    </TransactionsQuery>
  </div>;
};
