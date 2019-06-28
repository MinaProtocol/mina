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
  module BlockReward = {
    type feeTransfer = {
      .
      "recipient": PublicKey.t,
      "fee": int64,
    };

    type t = {
      date: Js.Date.t,
      creator: PublicKey.t,
      coinbase: int64,
      feeTransfers: array(feeTransfer),
    };
  };

  module PaymentDetails = {
    type t = {
      isDelegation: bool,
      from: PublicKey.t,
      to_: PublicKey.t,
      amount: int64,
      fee: int64,
      memo: string,
      date: option(Js.Date.t),
    };
  };

  type t =
    | UserCommand(PaymentDetails.t)
    | BlockReward(BlockReward.t);
};

module ViewModel = {
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
      | Memo(string, option(Js.Date.t))
      | StakingReward(list((PublicKey.t, int64)), option(Js.Date.t))
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
      (transaction: Transaction.t, ~myWallets: list(PublicKey.t), ~pending) => {
    switch (transaction) {
    | UserCommand(userCmd) => {
        sender: Actor.Key(userCmd.from),
        recipient: Actor.Key(userCmd.to_),
        action: pending ? Action.Pending : Action.Transfer,
        info: Info.Memo(userCmd.memo, userCmd.date),
        amountDelta:
          Caml.List.exists(PublicKey.equal(userCmd.from), myWallets)
            ? Int64.(neg(one)) *^ userCmd.amount -^ userCmd.fee
            : userCmd.amount,
      }
    | BlockReward({coinbase, creator, date, feeTransfers}) => {
        sender: Actor.Minted,
        recipient: Actor.Key(creator),
        action: Action.Transfer,
        info:
          Info.StakingReward(
            Array.map(
              ~f=transfer => (transfer##recipient, transfer##fee),
              feeTransfers,
            )
            |> Array.toList,
            Some(date),
          ),
        amountDelta: coinbase,
      }
    };
  };
};

module ActorName = {
  [@react.component]
  let make = (~value: ViewModel.Actor.t) => {
    switch (value) {
    | Key(key) => <AddressPill pubkey=key />
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
            merge([
              Theme.Text.Body.regular,
              style([
                display(`inlineBlock),
                width(`px(240)),
                overflow(`hidden),
                whiteSpace(`nowrap),
                textOverflow(`ellipsis),
              ]),
            ])
          )>
          children
        </p>
      </div>;
  };

  [@react.component]
  let make = (~viewModel: ViewModel.t) => {
    let activeWallet = Hooks.useActiveWallet();
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
       | MissingReceipts =>
         <MainRow>
           <Link> {React.string("+ Insert transaction receipts")} </Link>
         </MainRow>
       | StakingReward(rewards, _) =>
         <>
           <MainRow>
             <Link>
               {React.string(expanded ? "Collapse" : "Show fee transfers")}
             </Link>
           </MainRow>
           {expanded
              ? <ul className=Css.(style([margin(`zero), padding(`zero)]))>
                  {List.map(rewards, ~f=((pubkey, amount)) =>
                     <li
                       key={
                         PublicKey.toString(pubkey)
                         ++ Int64.to_string(amount)
                       }
                       className=Css.(
                         style([
                           display(`flex),
                           justifyContent(`spaceBetween),
                           alignItems(`center),
                           marginBottom(`rem(1.)),
                         ])
                       )>
                       <ActorName value={ViewModel.Actor.Key(pubkey)} />
                       <span>
                         <Amount
                           value={
                             Option.map(
                               ~f=PublicKey.equal(pubkey),
                               activeWallet,
                             )
                             |> Option.withDefault(~default=false)
                               ? amount : Int64.neg(amount)
                           }
                         />
                       </span>
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

    let mode =
      style([
        color(Theme.Colors.slateAlpha(1.)),
        display(`flex),
        alignItems(`center),
        marginTop(`rem(0.25)),
      ]);
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

  let icon = style([opacity(0.5)]);

  let pendingIcon =
    style([display(`inlineFlex), color(Theme.Colors.clay), opacity(0.5)]);

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
let make = (~transaction: Transaction.t, ~pending=false) => {
  let activeWallet = Hooks.useActiveWallet();
  let myWallets =
    Option.map(~f=wallet => [wallet], activeWallet)
    |> Option.withDefault(~default=[]);
  let viewModel = ViewModel.ofTransaction(transaction, ~myWallets, ~pending);

  <>
    <span className=TopLevelStyles.Actors.wrapper>
      <ActorName value={viewModel.sender} />
      <div className=TopLevelStyles.Actors.mode>
        {switch (viewModel.action) {
         | Transfer =>
           <span className=TopLevelStyles.icon>
             <Icon kind=Icon.BentArrow />
           </span>
         | Pending =>
           <span className=TopLevelStyles.pendingIcon>
             <Icon kind=Icon.Dots />
           </span>
         | Failed => React.string("x ")
         }}
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
             {switch (date) {
              | Some(date) => <TimeDisplay date />
              | None => React.null
              }}
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
