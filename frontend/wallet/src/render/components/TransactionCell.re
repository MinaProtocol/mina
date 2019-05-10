open Tc;

module Styles = {
  open Css;

  let pill =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`center),
      height(`rem(1.5)),
      padding2(~v=`px(0), ~h=`rem(0.5)),
      borderRadius(`px(4)),
      backgroundColor(lightgrey),
    ]);
};

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
      <span className=Styles.pill>
        {ReasonReact.string(PublicKey.toString(key))}
      </span>
    | Unknown => <span> {React.string("Unknown")} </span>
    | Minted =>
      <span className=Css.(style([backgroundColor(Theme.Colors.sage)]))>
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
    <span className=Css.(style([alignSelf(`flexEnd)]))>
      <span
        className=Css.(
          style([
            Theme.Typeface.lucidaGrande,
            color(
              value >= 0 ? Theme.Colors.serpentine : Theme.Colors.roseBud,
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
  let make = (~viewModel: ViewModel.t) => {
    let (expanded, setExpanded) = React.useState(() => false);
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
      </div>;
    };
    <div
      onClick={_e =>
        switch (viewModel.info) {
        | StakingReward(_, _) => setExpanded(expanded => !expanded)
        | _ => ()
        }
      }>
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

// These cells are returned as a fragment so that the parent container can
// use a consistent grid layout to keep everything lined up.

[@react.component]
let make = (~transaction: Transaction.t, ~myWallets: list(PublicKey.t)) => {
  let viewModel = ViewModel.ofTransaction(transaction, ~myWallets);

  <>
    <span>
      <ActorName value={viewModel.sender} />
      <div>
        {ReasonReact.string(
           switch (viewModel.action) {
           | Transfer => " -> "
           | Pending => " ... "
           | Failed => " x "
           },
         )}
        <ActorName value={viewModel.recipient} />
      </div>
    </span>
    <span
      className=Css.(
        style([verticalAlign(`baseline), width(`percent(100.))])
      )>
      <InfoSection viewModel />
    </span>
    <span className=Css.(style([justifySelf(`flexEnd)]))>
      <div
        className=Css.(style([display(`flex), justifyContent(`flexEnd)]))>
        {switch (viewModel.info) {
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
         }}
      </div>
      <Amount decorated=false value={viewModel.amountDelta} />
    </span>
  </>;
};
