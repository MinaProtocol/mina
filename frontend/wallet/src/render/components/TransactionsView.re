open Tc;

module Styles = {
  open Css;

  let container =
    style([
      height(`percent(100.)),
    ]);

  let row =
    style([
      display(`grid),
      gridTemplateColumns([`rem(16.), `fr(1.), `px(200)]),
      gridGap(Theme.Spacing.defaultSpacing),
      alignItems(`center),
      padding(`rem(1.)),
      borderBottom(`px(1), `solid, Theme.Colors.borderColor),
      lastChild([borderBottom(`px(0), `solid, white)]),
    ]);

  let headerRow =
    style([
      padding2(~v=`px(0), ~h=`rem(1.)),
      textTransform(`uppercase),
      height(`rem(2.)),
    ]);

  let body =
    style([
      width(`percent(100.)),
      overflow(`auto),
      maxHeight(`calc(`sub, `percent(100.), `rem(2.))),
    ]);
};

let myWallets = [PublicKey.ofStringExn("123456789")];
let otherKey = PublicKey.ofStringExn("BDK342322");

let mockTransactions =
  Array.fromList([
    TransactionCell.Transaction.Payment(
      {
        from: otherKey,
        to_: List.head(myWallets) |> Option.getExn,
        amount: 2415,
        fee: 10,
        memo: Some("Order #: 2347B342"),
        includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
        submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
      },
      {status: ConsensusState.Status.Failed, estimatedPercentConfirmed: 0.0},
    ),
    TransactionCell.Transaction.Unknown({
      key: List.head(myWallets) |> Option.getExn,
      amount: 2415,
    }),
    TransactionCell.Transaction.Payment(
      {
        from: List.head(myWallets) |> Option.getExn,
        to_: otherKey,
        amount: 1540,
        fee: 10,
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
      coinbase: 2000,
      transactionFees: 858,
      proofFees: 200,
      delegationFees: 215,
      includedAt: Js.Date.fromString("16 Apr 2019 21:46:00 PST"),
    }),
    TransactionCell.Transaction.Payment(
      {
        from: otherKey,
        to_: List.head(myWallets) |> Option.getExn,
        amount: 1540,
        fee: 10,
        memo: Some("Remitance payment"),
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
        amount: 2415,
        fee: 10,
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
    <div className={Css.merge([Styles.row, Styles.headerRow])}>
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
