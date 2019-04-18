open Tc;

module Transaction = {
  module RewardDetails = {
    type t = {
      key: PublicKey.t,
      coinbase: int,
      transactionFees: int,
      proofFees: int,
      delegationFees: int,
      includedAt: Js.Date.t,
    };
  };

  module PaymentDetails = {
    type t = {
      from: PublicKey.t,
      to_: PublicKey.t,
      amount: int,
      fee: int,
      memo: option(string),
      submittedAt: Js.Date.t,
      includedAt: option(Js.Date.t),
    };
  };

  module UnknownDetails = {
    type t = {
      key: PublicKey.t,
      amount: int,
    };
  };

  type t =
    | Minted(RewardDetails.t)
    | Payment(PaymentDetails.t, ConsensusState.t)
    | Unknown(UnknownDetails.t);
};

module ViewModel = {
  open Transaction;

  module Actor = {
    type t =
      | Minted
      | Key(PublicKey.t)
      | Unknown;
  };

  module Action = {
    type t =
      | Transfer
      | Pending
      | Failed;
  };

  module Info = {
    type t =
      | Memo(string, Js.Date.t)
      | Empty(Js.Date.t)
      | StakingReward(list((string, int)), Js.Date.t)
      | MissingReceipts;
  };

  type t = {
    sender: Actor.t,
    recipient: Actor.t,
    action: Action.t,
    info: Info.t,
    amountDelta: int // signed
  };

  let ofTransaction =
      (transaction: Transaction.t, ~myWallets: list(PublicKey.t)) => {
    switch (transaction) {
    | Minted({
        RewardDetails.key,
        coinbase,
        transactionFees,
        proofFees,
        delegationFees,
        includedAt,
      }) => {
        sender: Actor.Minted,
        recipient: Actor.Key(key),
        action: Action.Transfer,
        info:
          Info.StakingReward(
            [
              ("Coinbase", coinbase),
              ("Transaction fees", transactionFees),
              ("Proof fees", (-1) * proofFees),
              ("Delegation fees", (-1) * delegationFees),
            ],
            includedAt,
          ),
        amountDelta: coinbase + transactionFees - proofFees - delegationFees,
      }
    | Payment(
        {
          PaymentDetails.from,
          to_,
          amount,
          fee,
          memo,
          submittedAt,
          includedAt,
        },
        {ConsensusState.status, _},
      ) =>
      let date = Option.withDefault(includedAt, ~default=submittedAt);
      {
        sender: Actor.Key(from),
        recipient: Actor.Key(to_),
        action:
          switch (status) {
          | ConsensusState.Status.Failed => Action.Failed
          | Submitted => Action.Pending
          | Included
          | Snarked
          | Finalized => Action.Transfer
          },
        info:
          Option.map(memo, ~f=x => Info.Memo(x, date))
          |> Option.withDefault(~default=Info.Empty(date)),
        amountDelta:
          Caml.List.exists(PublicKey.equal(from), myWallets)
            ? (-1) * amount - fee : amount,
      };
    | Unknown({UnknownDetails.key, amount}) => {
        sender: Actor.Unknown,
        recipient: Actor.Key(key),
        action: Action.Transfer,
        info: Info.MissingReceipts,
        amountDelta: amount,
      }
    };
  };
};

module ActorName = {
  [@react.component]
  let make = (~value: ViewModel.Actor.t) => {
    switch (value) {
    | Key(key) =>
      <span> {ReasonReact.string(PublicKey.toString(key))} </span>
    | Unknown => <span />
    | Minted =>
      <span className=Css.(style([backgroundColor(StyleGuide.Colors.sage)]))>
        {ReasonReact.string("Minted")}
      </span>
    };
  };
};

module TimeDisplay = {
  [@react.component]
  let make = (~date: Js.Date.t) => {
    <span
      className=Css.(
        style([
          whiteSpace(`nowrap),
          overflow(`hidden),
          textOverflow(`ellipsis),
          maxWidth(`rem(6.0)),
        ])
      )>
       {ReasonReact.string(Js.Date.toString(date))} </span>;
      // TODO: Format properly
  };
};

module Amount = {
  [@react.component]
  let make = (~decorated: bool, ~value: int) => {
    <span>
      <span
        className=Css.(
          style([
            StyleGuide.Typeface.lucidaGrande,
            color(
              value >= 0
                ? StyleGuide.Colors.serpentine : StyleGuide.Colors.roseBud,
            ),
          ])
        )>
        {ReasonReact.string({j|■|j})}
      </span>
      <span> {ReasonReact.string(Js.Int.toString(value))} </span>
      {decorated
         ? <span> {ReasonReact.string(value >= 0 ? "+" : "-")} </span>
         : <span />}
    </span>;
  };
};

module InfoSection = {
  [@react.component]
  let make = (~expanded: bool, ~viewModel: ViewModel.t) => {
    let mainRow = message => {
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`spaceBetween),
            alignItems(`center),
          ])
        )>
        <p> {ReasonReact.string(message)} </p>
        <Amount decorated=false value={viewModel.amountDelta} />
      </div>;
    };
    <div>
      <div
        className=Css.(style([display(`flex), justifyContent(`flexEnd)]))>
        {expanded
           ? <span> {ReasonReact.string({j|Collapse 🠻|j})} </span>
           : (
             switch (viewModel.info) {
             | Memo(_, date)
             | Empty(date)
             | StakingReward(_, date) =>
               <>
                 {switch (viewModel.action) {
                  | Transfer => <span />
                  | Pending =>
                    <span className=Css.(style([textTransform(`uppercase)]))>
                      {ReasonReact.string("pending")}
                    </span>
                  | Failed =>
                    <span className=Css.(style([textTransform(`uppercase)]))>
                      {ReasonReact.string("failed")}
                    </span>
                  }}
                 <TimeDisplay date />
               </>
             | MissingReceipts => <span />
             }
           )}
      </div>
      {switch (viewModel.info) {
       | Memo(message, _) => mainRow(message)
       | Empty(_) => mainRow("")
       | MissingReceipts => mainRow("+ Insert transaction receipts")
       | StakingReward(rewards, _) =>
         <>
           {mainRow("Staking reward")}
           {expanded
              ? <ul>
                  {List.map(rewards, ~f=((message, amount)) =>
                     <li
                       key=message
                       className=Css.(
                         style([
                           display(`flex),
                           justifyContent(`spaceBetween),
                           alignItems(`center),
                         ])
                       )>
                       <p> {ReasonReact.string(message)} </p>
                       <Amount decorated=true value=amount />
                     </li>
                   )
                   |> Array.fromList
                   |> ReasonReact.array}
                </ul>
              : <span />}
         </>
       }}
    </div>;
  };
};

// We can represent one of these cells as a row in an HTML table in the
// following manner:
//
// ┌────────┬────┬───────────┬─────────────────────────
// │ Sender │ -> │ Recipient │ Info (including amount)
//
// The final column is info and amount in order to more easily support the
// expanded view of the staking reward

[@react.component]
let make = (~transaction: Transaction.t, ~myWallets: list(PublicKey.t)) => {
  let (expanded, setExpanded) = React.useState(() => false);

  let viewModel = ViewModel.ofTransaction(transaction, ~myWallets);

  <tr
    onClick={_e =>
      switch (viewModel.info) {
      | StakingReward(_, _) => setExpanded(expanded => !expanded)
      | _ => ()
      }
    }>
    <td className=Css.(style([verticalAlign(`baseline)]))>
      <ActorName value={viewModel.sender} />
    </td>
    <td className=Css.(style([verticalAlign(`baseline)]))>
      {ReasonReact.string(
         switch (viewModel.action) {
         | Transfer => "->"
         | Pending => ">>"
         | Failed => "x"
         },
       )}
    </td>
    <td className=Css.(style([verticalAlign(`baseline)]))>
      <ActorName value={viewModel.recipient} />
    </td>
    <td
      className=Css.(
        style([verticalAlign(`baseline), width(`percent(100.))])
      )>
      <InfoSection expanded viewModel />
    </td>
  </tr>;
};
