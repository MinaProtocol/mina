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

let myWallets = [PublicKey.ofStringExn("PUB_KEY_E9873DF4453213303DA61F2")];
let otherKey = PublicKey.ofStringExn("BDK342322");

let mockTransactions =
  Array.fromList([
    TransactionCell.Transaction.Unknown({
      key: List.head(myWallets) |> Option.getExn,
      amount: Int64.of_int(2415),
    }),
    TransactionCell.Transaction.Payment(
      {
        from: otherKey,
        to_: List.head(myWallets) |> Option.getExn,
        amount: Int64.of_int(2415),
        fee: Int64.of_int(10),
        memo: Some("Order #: 2347B342"),
        includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
        submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
      },
      {status: ConsensusState.Status.Failed, estimatedPercentConfirmed: 0.0},
    ),
    TransactionCell.Transaction.Payment(
      {
        from: List.head(myWallets) |> Option.getExn,
        to_: otherKey,
        amount: Int64.of_int(1540),
        fee: Int64.of_int(10),
        memo: Some("Funds sent"),
        includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
        submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
      },
      {
        status: ConsensusState.Status.Finalized,
        estimatedPercentConfirmed: 0.95,
      },
    ),
    TransactionCell.Transaction.Minted({
      key: List.head(myWallets) |> Option.getExn,
      coinbase: Int64.of_int(2000),
      transactionFees: Int64.of_int(858),
      proofFees: Int64.of_int(200),
      delegationFees: Int64.of_int(215),
      includedAt: Js.Date.fromString("16 Apr 2019 21:46:00 PST"),
    }),
    TransactionCell.Transaction.Payment(
      {
        from: otherKey,
        to_: List.head(myWallets) |> Option.getExn,
        amount: Int64.of_int(1540),
        fee: Int64.of_int(10),
        memo: Some("Remittance payment"),
        includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
        submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
      },
      {
        status: ConsensusState.Status.Submitted,
        estimatedPercentConfirmed: 0.0,
      },
    ),
    TransactionCell.Transaction.Payment(
      {
        from: otherKey,
        to_: List.head(myWallets) |> Option.getExn,
        amount: Int64.of_int(2415),
        fee: Int64.of_int(10),
        memo: Some("Order #: 2347B342"),
        includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
        submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
      },
      {status: ConsensusState.Status.Failed, estimatedPercentConfirmed: 0.0},
    ),
  ]);

[@react.component]
let make = () =>
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
    <div className=Styles.body>
      {Array.map(
         ~f=
           transaction =>
             <div className=Styles.row>
               <TransactionCell transaction myWallets />
             </div>,
         mockTransactions,
       )
       |> React.array}
    </div>
  </div>;
