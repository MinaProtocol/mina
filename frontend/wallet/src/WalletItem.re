type action =
  | Toggle;

module Styles = {
  open Css;
  open StyleGuide;

  let activeWalletItem = [color(white), backgroundColor(`hex("222b33CC"))];
  let walletItem =
    style([
      flexShrink(0),
      display(`flex),
      flexDirection(`column),
      fontFamily("IBM Plex Sans, Sans-Serif"),
      color(grey),
      backgroundColor(`hex("121f2b44")),
      margin(`px(2)),
      marginBottom(`px(0)),
      padding(`px(5)),
    ]);
  let inactiveWalletItem =
    merge([walletItem, style([hover(activeWalletItem)]), notText]);
  let activeWalletItem =
    merge([walletItem, style(activeWalletItem), notText]);
  ();

  let walletName = style([fontWeight(`num(500)), fontSize(`px(16))]);
  let walletNameTextField =
    style([
      paddingLeft(`em(0.5)),
      fontWeight(`num(500)),
      fontSize(`px(16)),
      backgroundColor(`rgba((0, 0, 0, 0.15))),
      color(`rgba((71, 137, 196, 0.5))),
      border(`px(2), solid, `hex("2a3f58")),
      width(`em(7.)),
      borderRadius(`px(1)),
    ]);

  let balance =
    style([
      fontWeight(`num(300)),
      marginTop(`em(0.25)),
      fontSize(`px(19)),
      height(`em(1.5)),
    ]);

  let separator =
    style([
      margin(`px(2)),
      border(`px(0), `solid, transparent),
      borderTop(`px(1), `solid, `hex("2a3f58")),
    ]);

  let settingLabel = style([marginLeft(`em(1.)), height(`em(1.5))]);

  let deleteButton =
    style([
      alignSelf(`center),
      width(`percent(100.)),
      backgroundColor(transparent),
      border(`px(0), `solid, transparent),
      color(`rgba((191, 40, 93, 0.5))),
      fontSize(`px(16)),
      outlineWidth(`px(0)),
    ]);
};

let component = ReasonReact.reducerComponent("WalletItem");

let make = (~name, ~balance, _children) => {
  ...component,
  initialState: () => false,
  reducer: (action, state) =>
    switch (action) {
    | Toggle => ReasonReact.Update(!state)
    },
  render: self => {
    <div
      className={
        self.state ? Styles.activeWalletItem : Styles.inactiveWalletItem
      }
      onClick={_event => self.send(Toggle)}>
      {if (self.state) {
         <input
           type_="text"
           className=Styles.walletNameTextField
           value=name
           readOnly=true
           onClick={e => ReactEvent.Synthetic.stopPropagation(e)}
         />;
       } else {
         <div className=Styles.walletName> {ReasonReact.string(name)} </div>;
       }}
      <div className=Styles.balance>
        {ReasonReact.string({js|■ |js} ++ string_of_float(balance))}
      </div>
      {if (self.state) {
         <>
           <hr className=Styles.separator />
           <div className=Styles.settingLabel>
             {ReasonReact.string("Staking")}
           </div>
           <hr className=Styles.separator />
           <div className=Styles.settingLabel>
             {ReasonReact.string("Private key")}
           </div>
           <hr className=Styles.separator />
           <button
             className=Styles.deleteButton
             onClick={_event => self.send(Toggle)}>
             {ReasonReact.string("Delete wallet")}
           </button>
         </>;
       } else {
         ReasonReact.null;
       }}
    </div>;
  },
};
