open Tc;

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

module Action = {
  type t =
    | SaveName
    | ChangeName(string)
    | LoadingDone
    | ResetDebounce
    | ToggleExpand;

  let print =
    fun
    | SaveName => "saveName"
    | ChangeName(_) => "changeName"
    | LoadingDone => "loadingDone"
    | ResetDebounce => "resetDebounce"
    | ToggleExpand => "toggleExpand";
};

module State = {
  module Visibility = {
    type t =
      | Shrunk
      | Loading
      | Expanded;
  };

  type t = {
    currentName: string,
    visibility: Visibility.t,
    // onBlur triggers before onClick of the parent div
    // and the settings reload is fast enough that the reload
    // finishes and then the click triggers an expansion again!
    //
    // This debounce (when enabled) ensures we ignore actions that
    // the user triggers
    debounce: bool,
  };
};

let useReducerWithDispatch = (reduceWithDispatch, initialState) => {
  let dispatchSelf = ref(ignore);
  let (state, dispatch) =
    React.useReducer(
      (state, action) =>
        reduceWithDispatch(action => dispatchSelf^(action), state, action),
      initialState,
    );
  dispatchSelf := dispatch;
  (state, dispatch);
};

[@react.component]
let make = (~wallet: Wallet.t, ~settings, ~setSettingsOrError) => {
  let (state: State.t, dispatch) =
    useReducerWithDispatch(
      (dispatch, state: State.t, action) => {
        Js.log4(
          "Getting action",
          Action.print(action),
          state,
          state.debounce,
        );
        switch (action) {
        | Action.ChangeName(newName) => {...state, currentName: newName}
        | ToggleExpand =>
          switch (state.visibility, state.debounce) {
          | (Shrunk, false) => {...state, visibility: Expanded}
          | (Expanded, false) => {...state, visibility: Shrunk}
          // ignore these ones
          | (Shrunk, true)
          | (Expanded, true)
          | (Loading, _) => state
          }
        | LoadingDone => {...state, visibility: Shrunk}
        | ResetDebounce => {...state, debounce: false}
        | SaveName =>
          let _ = Js.Global.setTimeout(() => dispatch(ResetDebounce), 100);
          Task.perform(
            SettingsRenderer.add(
              settings,
              ~key=wallet.key,
              ~name=state.currentName,
            ),
            ~f=settingsOrError => {
              setSettingsOrError(settingsOrError);
              // TODO: Loading needs to be on the whole wallet-item pane since
              // Settings updates are not commutative
              dispatch(LoadingDone);
            },
          );
          {...state, State.visibility: Loading, debounce: true};
        };
      },
      {
        State.currentName:
          SettingsRenderer.lookupWithFallback(settings, wallet.key),
        visibility: Shrunk,
        debounce: false,
      },
    );

  <div
    className={
      switch (state.visibility) {
      | Shrunk => Styles.inactiveWalletItem
      | Expanded => Styles.activeWalletItem
      | Loading => Css.(style([backgroundColor(`rgb((255, 0, 0)))]))
      }
    }
    onClick={_event => dispatch(ToggleExpand)}>
    {switch (state.visibility) {
     | Shrunk =>
       <div className=Styles.walletName>
         {ReasonReact.string(state.currentName)}
       </div>
     | Expanded =>
       <input
         type_="text"
         className=Styles.walletNameTextField
         value={state.currentName}
         onBlur={_ => dispatch(SaveName)}
         onChange={e =>
           dispatch(ChangeName(ReactEvent.Synthetic.target(e)##value))
         }
         onClick={e => ReactEvent.Synthetic.stopPropagation(e)}
       />
     | Loading => <div> {ReasonReact.string("LOADING")} </div>
     }}
    <div className=Styles.balance>
      {ReasonReact.string({js|■ |js} ++ Js.Int.toString(wallet.balance))}
    </div>
    {switch (state.visibility) {
     | Shrunk
     | Loading => ReasonReact.null
     | Expanded =>
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
           onClick={_event => dispatch(ToggleExpand)}>
           {ReasonReact.string("Delete wallet")}
         </button>
       </>
     }}
  </div>;
};
