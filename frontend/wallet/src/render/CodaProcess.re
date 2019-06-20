open Tc;

module Action = {
  let debounceTimeout = 4000;

  type t =
    | Stabilize
    | GraphQlFailure
    | StartDebounceTimer([ | `Canceller(unit => unit)])
    | ChangeArgs(list(string))
    | ForceStartCoda;
};

module State = {
  module Mode = {
    type t =
      | Stable
      | WaitTriggerFirstBounce
      | WaitForceStart
      | PendingRestart([ | `Canceller(unit => unit)]);
  };

  type t = {
    args: list(string),
    mode: Mode.t,
  };
};
module O = Hooks.Reducer.Update;

let reduce = (acc, action) => {
  let forceStartCoda = () =>
    MainCommunication.controlCodaDaemon(Some(acc.State.args));

  let doFirstBounce = args =>
    O.UpdateWithSideEffects(
      {State.args, mode: WaitTriggerFirstBounce},
      (~dispatch, _) => {
        let (canceller, task) = Bindings.setTimeout(Action.debounceTimeout);
        Task.perform(
          task,
          ~f=
            fun
            | `Cancelled => ()
            | `Finished => dispatch(Action.ForceStartCoda),
        );
        dispatch(StartDebounceTimer(canceller));
      },
    );

  switch (action, acc.mode) {
  | (Action.Stabilize, State.Mode.Stable) => O.NoUpdate
  | (Stabilize, PendingRestart(`Canceller(cancel))) =>
    O.UpdateWithSideEffects(
      {...acc, mode: Stable},
      (~dispatch as _, _) => cancel(),
    )
  | (Stabilize, _) => O.Update({...acc, mode: Stable})

  | (Action.GraphQlFailure, State.Mode.Stable) => doFirstBounce(acc.args)
  | (GraphQlFailure, WaitTriggerFirstBounce)
  | (GraphQlFailure, WaitForceStart)
  | (GraphQlFailure, PendingRestart(_)) => O.NoUpdate

  // always save the debounce timer canceller
  // or else we'll have a rogue setTimeout hanging around
  | (StartDebounceTimer(canceller), _) =>
    O.Update({...acc, mode: PendingRestart(canceller)})

  // we always want to change args, sometimes we'll trigger the first bounce
  | (ChangeArgs(args), Stable) => doFirstBounce(args)
  | (ChangeArgs(args), WaitTriggerFirstBounce)
  | (ChangeArgs(args), WaitForceStart)
  | (ChangeArgs(args), PendingRestart(_)) => O.Update({...acc, args})

  | (ForceStartCoda, Stable) =>
    O.UpdateWithSideEffects(
      {...acc, mode: WaitForceStart},
      (~dispatch, _) => {
        forceStartCoda();
        dispatch(Stabilize);
      },
    )
  | (ForceStartCoda, WaitTriggerFirstBounce) =>
    // we'll stay in WaitTriggerFirstBounce until this effect happens
    O.SideEffects(
      (~dispatch, _) =>
        // Since we always WaitTriggerFirstBounce
        // only while waiting for side-effects to run, we'll
        // be in the PendingRestart state when this effect runs
        dispatch(ForceStartCoda),
    )
  // we're already about to force start, no need to start again
  | (ForceStartCoda, WaitForceStart) => O.NoUpdate
  | (ForceStartCoda, PendingRestart(`Canceller(cancel))) =>
    O.UpdateWithSideEffects(
      {...acc, mode: WaitForceStart},
      (~dispatch, _) => {
        forceStartCoda();
        cancel();
        dispatch(Stabilize);
      },
    )
  };
};

let defaultNetwork = "testnet.codaprotocol.com";
let getLocalStorageNetwork = () => {
  Bindings.(
    switch (Js.Nullable.toOption(LocalStorage.getItem(`Network))) {
    | Some(x) => x
    | None =>
      LocalStorage.setItem(~key=`Network, ~value=defaultNetwork);
      defaultNetwork;
    }
  );
};

let useHook = () => {
  let (_state, dispatch) =
    Hooks.Reducer.useReducer(reduce, {State.args: [], mode: Stable});

  let () =
    React.useEffect0(() => {
      let token = MainCommunication.listen();
      dispatch(Action.ChangeArgs(["-peer", getLocalStorageNetwork()]));
      Some(() => MainCommunication.stopListening(token));
    });

  dispatch;
};
