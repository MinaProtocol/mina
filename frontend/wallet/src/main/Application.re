module Action = {
  type t =
    | DoAction;
};

module State = {
  type t('a) = unit;
};

let reduce = _acc =>
  fun
  | Action.DoAction => ();

module Store = {
  type t('a) = {
    mutable state: State.t('a),
    onNewState: (State.t('a), State.t('a)) => unit,
  };

  let create = (initialState, ~onNewState) => {
    state: initialState,
    onNewState,
  };

  let apply = (store, action) => {
    let oldState = store.state;
    store.state = reduce(store.state, action);
    store.onNewState(oldState, store.state);
  };
};
