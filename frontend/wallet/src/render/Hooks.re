let useActiveAccount = () => {
  let url = ReasonReact.Router.useUrl();
  switch (url.path) {
  | ["account", accountKey] => Some(PublicKey.uriDecode(accountKey))
  | ["settings", accountKey, ..._] => Some(PublicKey.uriDecode(accountKey))
  | _ => None
  };
};

let useToast = () => {
  let (_, setToast) = React.useContext(ToastProvider.context);
  (toastText, toastType) => {
    let id = Js.Global.setTimeout(() => setToast(_ => None), 2000);

    setToast(currentToast => {
      switch (currentToast) {
      | Some(currentToast) => Js.Global.clearTimeout(currentToast.timeoutId)
      | None => ()
      };
      Some({text: toastText, style: toastType, timeoutId: id});
    });
  };
};

[@bs.scope "window"] [@bs.val] external fileRoot: string = "fileRoot";
let useAsset = fileName => Filename.concat(fileRoot, fileName);

// Vanilla React.useReducer aren't supposed to have any effects themselves.
// The following supports the handling of the effects.
//
// Adapted from https://gist.github.com/bloodyowl/64861aaf1f53cfe0eb340c3ea2250b47
//
module Reducer = {
  open Tc;

  module Update = {
    type t('action, 'state) =
      | NoUpdate
      | Update('state)
      | UpdateWithSideEffects(
          'state,
          (~dispatch: 'action => unit, 'state) => unit,
        )
      | SideEffects((~dispatch: 'action => unit, 'state) => unit);
  };

  module FullState = {
    type t('action, 'state) = {
      state: 'state,
      mutable sideEffects: list((~dispatch: 'action => unit, 'state) => unit),
    };
  };

  let useReducer = (reducer, initialState) => {
    let (fullState, dispatch) =
      React.useReducer(
        ({FullState.state, sideEffects} as fullState, action) =>
          switch (reducer(state, action)) {
          | Update.NoUpdate => fullState
          | Update(state) => {...fullState, state}
          | UpdateWithSideEffects(state, sideEffect) => {
              state,
              sideEffects: [sideEffect, ...sideEffects],
            }
          | SideEffects(sideEffect) => {
              ...fullState,
              sideEffects: [sideEffect, ...sideEffects],
            }
          },
        {FullState.state: initialState, sideEffects: []},
      );
    React.useEffect1(
      () => {
        if (List.length(fullState.sideEffects) > 0) {
          List.iter(List.reverse(fullState.sideEffects), ~f=run =>
            run(~dispatch, fullState.state)
          );
          fullState.sideEffects = [];
        };
        None;
      },
      [|fullState.sideEffects|],
    );
    (fullState.state, dispatch);
  };
};