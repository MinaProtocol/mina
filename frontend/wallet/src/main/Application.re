open Tc;

module Action = {
  type t =
    | SettingsUpdate((PublicKey.t, string))
    | NewSettings(Settings.t)
    | WalletInfo(array({. "publicKey": string}));
};

module State = {
  type t('a) = {
    settingsOrError:
      Result.t(
        [> | `Decode_error(string) | `Json_parse_error] as 'a,
        Settings.t,
      ),
    wallets: array({. "publicKey": string}),
  };
};

let reduce = acc =>
  fun
  | Action.NewSettings(settings) => {
      ...acc,
      State.settingsOrError: Result.return(settings),
    }
  | WalletInfo(wallets) => {...acc, State.wallets}
  | SettingsUpdate((key, name)) => {
      ...acc,
      State.settingsOrError:
        switch (acc.settingsOrError) {
        | Belt.Result.Ok(settings) =>
          Ok(Settings.set(settings, ~key, ~name))
        | Error(_) => acc.settingsOrError
        },
    };

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
