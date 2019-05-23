open Tc;

let (+^) = Int64.add;
let ( *^ ) = Int64.mul;
let (-^) = Int64.sub;
let (>=^) = (a, b) => Int64.compare(a, b) >= 0;
let (<=^) = (a, b) => Int64.compare(a, b) <= 0;

module Styles = {
  open Css;

  let pill =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`center),
      paddingTop(`px(2)),
      height(`rem(1.5)),
      marginBottom(`px(4)),
      padding2(~v=`px(0), ~h=`rem(0.5)),
      borderRadius(`px(4)),
      backgroundColor(Theme.Colors.slateAlpha(0.2)),
    ]);
};

module Transaction = {
  module RewardDetails = {
    type t = {
      key: PublicKey.t,
      coinbase: int64,
      transactionFees: int64,
      proofFees: int64,
      delegationFees: int64,
      includedAt: Js.Date.t,
    };
  };

  module PaymentDetails = {
    type t = {
      from: PublicKey.t,
      to_: PublicKey.t,
      amount: int64,
      fee: int64,
      memo: option(string),
      submittedAt: Js.Date.t,
      includedAt: option(Js.Date.t),
    };
  };

  module UnknownDetails = {
    type t = {
      key: PublicKey.t,
      amount: int64,
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
      | StakingReward(list((string, int64)), Js.Date.t)
      | MissingReceipts;
  };

  type t = {
    sender: Actor.t,
    recipient: Actor.t,
    action: Action.t,
    info: Info.t,
    amountDelta: int64 // signed
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
              ("Proof fees", Int64.(neg(one) *^ proofFees)),
              ("Delegation fees", Int64.(neg(one) *^ delegationFees)),
            ],
            includedAt,
          ),
        amountDelta:
          coinbase +^ transactionFees -^ proofFees -^ delegationFees,
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
            ? Int64.(neg(one)) *^ amount -^ fee : amount,
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
    let activeWallet = Hooks.useActiveWallet();
    let (settings, _) = React.useContext(AddressBookProvider.context);
    switch (value) {
    | Key(key) =>
      <Pill mode={activeWallet === Some(key) ? Pill.Blue : Pill.Grey}>
        <span
          className=Css.(
            merge([
              Option.isSome(AddressBook.lookup(settings, key))
                ? Theme.Text.Body.regular : Theme.Text.mono,
              style([
                color(
                  activeWallet === Some(key)
                    ? Theme.Colors.marineAlpha(1.) : Theme.Colors.midnight,
                ),
                opacity(0.7),
              ]),
            ])
          )>
          {ReasonReact.string(AddressBook.getWalletName(settings, key))}
        </span>
      </Pill>
    | Unknown =>
      <Pill>
        <span
          className=Css.(
            merge([
              Theme.Text.Body.regular,
              style([color(Theme.Colors.midnight), opacity(0.7)]),
            ])
          )>
          {React.string("Unknown")}
        </span>
      </Pill>
    | Minted =>
      <Pill mode=Pill.Green>
        <span
          className=Css.(
            merge([
              Theme.Text.Body.regular,
              style([color(Theme.Colors.serpentine)]),
            ])
          )>
          {ReasonReact.string("Minted")}
        </span>
      </Pill>
    };
  };
};

module TimeDisplay = {
  module Styles = {
    open Css;

    let time =
      merge([
        Theme.Text.Body.small,
        style([
          color(Theme.Colors.greyish(0.5)),
          whiteSpace(`nowrap),
          overflow(`hidden),
          textOverflow(`ellipsis),
          maxWidth(`rem(10.0)),
        ]),
      ]);
  };

  [@react.component]
  let make = (~date: Js.Date.t) => {
    <span className=Styles.time>
      {ReasonReact.string(Time.render(~date, ~now=Js.Date.make()))}
    </span>;
  };
};

module Amount = {
  module Styles = {
    open Css;
    let square = value =>
      style([
        Theme.Typeface.lucidaGrande,
        color(
          value >=^ Int64.zero
            ? Theme.Colors.serpentine : Theme.Colors.roseBud,
        ),
      ]);

    let currency =
      style([color(Theme.Colors.greenblack), Theme.Typeface.plex]);
  };

  [@react.component]
  let make = (~value: int64) => {
    <>
      <span className={Styles.square(value)}>
        {ReasonReact.string({j|■|j})}
      </span>
      <span className=Styles.currency>
        {ReasonReact.string(
           " "
           ++ Int64.to_string(
                value < Int64.zero ? value *^ Int64.(neg(one)) : value,
              ),
         )}
      </span>
      {value <=^ Int64.zero
         ? <span> {ReasonReact.string(" -")} </span> : <span />}
    </>;
  };
};

module InfoSection = {
  module MainRow = {
    [@react.component]
    let make = (~children) =>
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`spaceBetween),
            alignItems(`center),
            color(Theme.Colors.midnight),
          ])
        )>
        <p
          className=Css.(
            merge([Theme.Text.Body.regular, style([display(`flex)])])
          )>
          children
        </p>
      </div>;
  };

  [@react.component]
  let make = (~viewModel: ViewModel.t) => {
    let (expanded, setExpanded) = React.useState(() => false);
    <div
      onClick={_e =>
        switch (viewModel.info) {
        | StakingReward(_, _) => setExpanded(expanded => !expanded)
        | _ => ()
        }
      }>
      {switch (viewModel.info) {
       | Memo(message, _) => <MainRow> {React.string(message)} </MainRow>
       | Empty(_) => <MainRow> {React.string("")} </MainRow>
       | MissingReceipts =>
         <MainRow>
           <Link> {React.string("+ Insert transaction receipts")} </Link>
         </MainRow>
       | StakingReward(rewards, _) =>
         <>
           <MainRow>
             <Link> {React.string(expanded ? "Collapse" : "Details")} </Link>
           </MainRow>
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
                       <Amount value=amount />
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

// Making a separate styles module here to collocate the styles in the below
// make function closer to the layout
module TopLevelStyles = {
  open Css;

  module Actors = {
    let wrapper = style([padding2(~h=`zero, ~v=`rem(0.625))]);

    let mode = style([marginTop(`rem(0.25))]);
  };

  let infoSection =
    style([
      verticalAlign(`baseline),
      width(`percent(100.)),
      height(`calc((`sub, `percent(100.0), `rem(0.75)))),
      marginTop(`rem(0.75)),
      display(`flex),
      alignItems(`center),
    ]);

  module RightSide = {
    let outerWrapper =
      style([
        justifySelf(`flexEnd),
        marginTop(`rem(0.25)),
        width(`percent(100.)),
      ]);

    let topInfoWrapper =
      style([
        display(`flex),
        justifyContent(`flexEnd),
        height(`rem(1.25)),
      ]);

    let amount =
      style([
        textAlign(`right),
        display(`inlineBlock),
        padding2(~v=`zero, ~h=`rem(0.625)),
        width(`percent(100.)),
        marginTop(`rem(0.5)),
      ]);

    let action =
      merge([Theme.Text.Body.small, style([marginRight(`rem(1.0))])]);
  };
};

// These cells are returned as a fragment so that the parent container can
// use a consistent grid layout to keep everything lined up.
[@react.component]
let make = (~transaction: Transaction.t, ~myWallets: list(PublicKey.t)) => {
  let viewModel = ViewModel.ofTransaction(transaction, ~myWallets);

  <>
    <span className=TopLevelStyles.Actors.wrapper>
      <ActorName value={viewModel.sender} />
      <div className=TopLevelStyles.Actors.mode>
        {React.string(
           switch (viewModel.action) {
           | Transfer => "-> "
           | Pending => "... "
           | Failed => "x "
           },
         )}
        <ActorName value={viewModel.recipient} />
      </div>
    </span>
    <span className=TopLevelStyles.infoSection>
      <InfoSection viewModel />
    </span>
    <span className=TopLevelStyles.RightSide.outerWrapper>
      <div className=TopLevelStyles.RightSide.topInfoWrapper>
        {switch (viewModel.info) {
         | Memo(_, date)
         | Empty(date)
         | StakingReward(_, date) =>
           <>
             {switch (viewModel.action) {
              | Transfer => <span />
              | Pending =>
                <span
                  className=Css.(
                    merge([
                      TopLevelStyles.RightSide.action,
                      style([color(Theme.Colors.pendingOrange)]),
                    ])
                  )>
                  {ReasonReact.string("Pending")}
                </span>
              | Failed =>
                <span
                  className=Css.(
                    merge([
                      TopLevelStyles.RightSide.action,
                      style([color(Theme.Colors.roseBud)]),
                    ])
                  )>
                  {ReasonReact.string("Failed")}
                </span>
              }}
             <TimeDisplay date />
           </>
         | MissingReceipts => <span />
         }}
      </div>
      <span className=TopLevelStyles.RightSide.amount>
        <Amount value={viewModel.amountDelta} />
      </span>
    </span>
  </>;
};
