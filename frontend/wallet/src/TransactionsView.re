open Tc;

[@react.component]
let make = () => {
  let myWallets = [PublicKey.ofStringExn("123456789")];
  let otherKey = PublicKey.ofStringExn("BDK342322");

  <table className=Css.(style([overflow(`scroll)]))>
    <tr>
      <th className=Css.(style([textAlign(`left)]))>
        {ReasonReact.string("Sender")}
      </th>
      <th />
      <th className=Css.(style([textAlign(`left)]))>
        {ReasonReact.string("Recipient")}
      </th>
      <th className=Css.(style([textAlign(`left)]))>
        {ReasonReact.string("Info")}
      </th>
    </tr>
    // Transaction Cells as in the mockup
    <TransactionCell
      transaction={
        TransactionCell.Transaction.Unknown({
          key: List.head(myWallets) |> Option.getExn,
          amount: 2415,
        })
      }
      myWallets
    />
    <TransactionCell
      transaction={
        TransactionCell.Transaction.Payment(
          {
            from: otherKey,
            to_: List.head(myWallets) |> Option.getExn,
            amount: 2415,
            fee: 10,
            memo: Some("Funds received memo"),
            includedAt: Some(Js.Date.fromString("16 Apr 2019 21:46:00 PST")),
            submittedAt: Js.Date.fromString("15 Apr 2019 21:46:00 PST"),
          },
          {
            status: ConsensusState.Status.Included,
            estimatedPercentConfirmed: 0.95,
          },
        )
      }
      myWallets
    />
    <TransactionCell
      transaction={
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
        )
      }
      myWallets
    />
    <TransactionCell
      transaction={
        TransactionCell.Transaction.Minted({
          key: List.head(myWallets) |> Option.getExn,
          coinbase: 2000,
          transactionFees: 858,
          proofFees: 200,
          delegationFees: 215,
          includedAt: Js.Date.fromString("16 Apr 2019 21:46:00 PST"),
        })
      }
      myWallets
    />
    <TransactionCell
      transaction={
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
        )
      }
      myWallets
    />
    <TransactionCell
      transaction={
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
          {
            status: ConsensusState.Status.Failed,
            estimatedPercentConfirmed: 0.0,
          },
        )
      }
      myWallets
    />
  </table>;
};
