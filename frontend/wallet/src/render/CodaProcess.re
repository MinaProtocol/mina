module Action = {
  type t =
    | GraphQlFailure
    | StartCoda(list(string));
};

module State = {
  module Mode = {
    type t =
      | Stable
      | Crashed;
  };

  type t = {
    args: list(string),
    mode: Mode.t,
  };
};

module O = Hooks.Reducer.Update;

let reduce = (acc, action) =>
  switch ((action: Action.t)) {
  | GraphQlFailure => O.Update({...acc, State.mode: Crashed})
  | StartCoda(args) =>
    O.UpdateWithSideEffects(
      {mode: Stable, State.args},
      (~dispatch as _, state) =>
        ignore(MainCommunication.controlCodaDaemon(Some(state.args))),
    )
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
      let args =
        switch (getLocalStorageNetwork()) {
        | "" => []
        | s => ["-peer", s]
        };
      dispatch(Action.StartCoda(args));
      Some(() => MainCommunication.stopListening(token));
    });

  dispatch;
};
