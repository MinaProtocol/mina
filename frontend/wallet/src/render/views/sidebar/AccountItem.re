open Tc;

module Styles = {
  open Css;
  open Theme;

  let accountItem =
    style([
      position(`relative),
      flexShrink(0),
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`center),
      height(`rem(4.5)),
      fontFamily("IBM Plex Sans, Sans-Serif"),
      color(Colors.slateAlpha(0.5)),
      padding2(~v=`px(0), ~h=`rem(1.25)),
      borderBottom(`px(1), `solid, Colors.borderColor),
      borderTop(`px(1), `solid, white),
    ]);

  let inactiveAccountItem =
    merge([accountItem, style([hover([color(Colors.saville)])]), notText]);

  let activeAccountItem =
    merge([
      accountItem,
      style([
        color(Colors.marine),
        backgroundColor(Colors.hyperlinkAlpha(0.15)),
      ]),
      notText,
    ]);

  let activeIndicator =
    style([
      position(`absolute),
      top(`zero),
      left(`zero),
      bottom(`zero),
      width(`rem(0.25)),
      backgroundColor(Colors.marine),
    ]);

  let balance =
    style([
      fontWeight(`num(500)),
      marginTop(`rem(-0.25)),
      fontSize(`rem(1.25)),
      height(`rem(1.5)),
      marginBottom(`rem(0.25)),
    ]);

  let lockIcon =
    style([position(`absolute), top(`px(4)), right(`px(4))]);
};

module LockAccount = [%graphql
  {|
  mutation lockWallet($publicKey: PublicKey!) {
    lockWallet(input: { publicKey: $publicKey }) { publicKey }
  } |}
];

module LockAccountMutation = ReasonApollo.CreateMutation(LockAccount);

[@react.component]
let make = (~account: Account.t) => {
  let isActive =
    Option.map(Hooks.useActiveAccount(), ~f=activeAccount =>
      PublicKey.equal(activeAccount, account.publicKey)
    )
    |> Option.withDefault(~default=false);

  let isLocked = Option.withDefault(~default=true, account.locked);
  let (showModal, setModalOpen) = React.useState(() => false);
  <div
    className={
      isActive ? Styles.activeAccountItem : Styles.inactiveAccountItem
    }
    onClick={_ =>
      ReasonReact.Router.push(
        "/account/" ++ PublicKey.uriEncode(account.publicKey),
      )
    }>
    {isActive ? <div className=Styles.activeIndicator /> : React.null}
    <AccountName
      pubkey={account.publicKey}
      className=Theme.Text.Body.smallCaps
    />
    <div className=Styles.balance>
      <span className=Css.(style([paddingBottom(px(2))]))>
        {React.string({js|■ |js})}
      </span>
      {ReasonReact.string(Int64.to_string(account.balance##total))}
    </div>
    <LockAccountMutation>
      {(lockAccount, _) => {
         let variables =
           LockAccount.make(
             ~publicKey=Apollo.Encoders.publicKey(account.publicKey),
             (),
           )##variables;
         <div
           onClick={evt => {
             ReactEvent.Synthetic.stopPropagation(evt);
             isLocked
               ? setModalOpen(_ => true)
               : lockAccount(
                   ~variables,
                   ~refetchQueries=[|"getWallets", "accountLocked"|],
                   (),
                 )
                 |> ignore;
           }}
           className=Styles.lockIcon>
           <Icon kind={isLocked ? Icon.Locked : Icon.Unlocked} />
         </div>;
       }}
    </LockAccountMutation>
    {showModal
       ? <UnlockModal
           account={account.publicKey}
           onClose={() => setModalOpen(_ => false)}
           onSuccess={() => setModalOpen(_ => false)}
         />
       : React.null}
  </div>;
};
