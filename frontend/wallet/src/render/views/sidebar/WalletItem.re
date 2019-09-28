open Tc;

module Styles = {
  open Css;
  open Theme;

  let walletItem =
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

  let inactiveWalletItem =
    merge([walletItem, style([hover([color(Colors.saville)])]), notText]);

  let activeWalletItem =
    merge([
      walletItem,
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

module LockWallet = [%graphql
  {|
  mutation lockWallet($publicKey: PublicKey!) {
    lockWallet(input: { publicKey: $publicKey }) { publicKey }
  } |}
];

module LockWalletMutation = ReasonApollo.CreateMutation(LockWallet);

[@react.component]
let make = (~wallet: Wallet.t) => {
  let isActive =
    Option.map(Hooks.useActiveWallet(), ~f=activeWallet =>
      PublicKey.equal(activeWallet, wallet.publicKey)
    )
    |> Option.withDefault(~default=false);

  let isLocked = Option.withDefault(~default=true, wallet.locked);
  let (showModal, setModalOpen) = React.useState(() => false);
  <div
    className={isActive ? Styles.activeWalletItem : Styles.inactiveWalletItem}
    onClick={_ =>
      ReasonReact.Router.push(
        "/wallet/" ++ PublicKey.uriEncode(wallet.publicKey),
      )
    }>
    {isActive ? <div className=Styles.activeIndicator /> : React.null}
    <WalletName
      pubkey={wallet.publicKey}
      className=Theme.Text.Body.smallCaps
    />
    <div className=Styles.balance>
      <span className=Css.(style([paddingBottom(px(2))]))>
        {React.string({js|■ |js})}
      </span>
      {ReasonReact.string(Int64.to_string(wallet.balance##total))}
    </div>
    <LockWalletMutation>
      {(lockWallet, _) => {
         let variables =
           LockWallet.make(
             ~publicKey=Apollo.Encoders.publicKey(wallet.publicKey),
             (),
           )##variables;
         <div
           onClick={evt => {
             ReactEvent.Synthetic.stopPropagation(evt);
             isLocked
               ? setModalOpen(_ => true)
               : lockWallet(~variables, ~refetchQueries=[|"getWallets"|], ())
                 |> ignore;
           }}
           className=Styles.lockIcon>
           <Icon kind={isLocked ? Icon.Locked : Icon.Unlocked} />
         </div>;
       }}
    </LockWalletMutation>
    {showModal
       ? <UnlockModal
           onClose={() => setModalOpen(_ => false)}
           wallet={wallet.publicKey}
         />
       : React.null}
  </div>;
};
