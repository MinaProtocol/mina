open Tc;

module State = {
  module CodaProcessState = {
    type t('proc) =
      // the process is stopped
      // it can be stopped unexpectedly with a string
      | Stopped(Result.t(string, unit))
      // we started it with the following extra arguments
      | Started(list(string), Messages.CallTable.Ident.Encode.Set.t, 'proc)
      // the process is ready for GraphQL interaction
      | Ready(list(string), 'proc);

    let toString =
      fun
      | Stopped(res) => "Stopped(" ++ Js.String.make(res) ++ ")"
      | Started(args, ident, proc) =>
        "Started("
        ++ Js.String.make(args)
        ++ ";;"
        ++ Js.String.make(ident)
        ++ ";;"
        ++ Js.String.make(proc)
        ++ ")"
      | Ready(args, proc) =>
        "Ready("
        ++ Js.String.make(args)
        ++ ";;"
        ++ Js.String.make(proc)
        ++ ")";
  };

  type t('proc, 'window) = {
    wallets: array({. "publicKey": string}),
    coda: CodaProcessState.t('proc),
    window: option('window),
  };

  let toString = ({coda, _}) => CodaProcessState.toString(coda);
};

module Make =
       (
         CodaProcess: {
           type t;

           let kill: t => unit;

           let start:
             list(string) =>
             Result.t(string, (t, Task.t('x, [> | `Ready])));
         },
         Window: {
           type t;

           let send: (t, Messages.mainToRendererMessages) => unit;
         },
       ) => {
  module IdentSet = Messages.CallTable.Ident.Encode.Set;

  let reduce = (~dispatch, acc) => {
    let resolve = (idents, res) => {
      Option.iter(acc.State.window, ~f=window =>
        idents
        |> IdentSet.iter(ident =>
             Window.send(window, `Respond_control_coda((ident, res)))
           )
      );
    };

    fun
    | Action.PutWindow(windowOpt) => {...acc, State.window: windowOpt}
    | WalletInfo(wallets) => {...acc, State.wallets}
    | CodaGraphQLReady(args) => {
        ...acc,
        State.coda:
          switch (acc.coda) {
          | State.CodaProcessState.Started(args', idents, proc)
              when List.equal(~a_equal=(==), args, args') =>
            resolve(idents, Belt.Result.Ok(true));
            State.CodaProcessState.Ready(args, proc);
          | Ready(args', proc) when List.equal(~a_equal=(==), args, args') =>
            Ready(args, proc)
          | Ready(_, _) => acc.coda
          | Started(_, idents, _) =>
            resolve(
              idents,
              Belt.Result.Error(
                "Args are different from what we expect, coda probably started weirdly",
              ),
            );
            acc.coda;
          | Stopped(_) => acc.coda
          },
      }
    | ControlCoda(maybeArgs, pendingIdent) => {
        let resolve = (res, extraIdents) =>
          resolve(IdentSet.add(pendingIdent, extraIdents), res);

        let resolveKilled = resolve(Belt.Result.Ok(false));
        let resolveReady = resolve(Belt.Result.Ok(true));
        let resolveFailed = str => resolve(Belt.Result.Error(str));

        let startCoda = (extraIdents, args) => {
          switch (CodaProcess.start(args)) {
          | Belt.Result.Ok((p, readyTask)) =>
            Task.perform(readyTask, ~f=(`Ready) =>
              dispatch(Action.CodaGraphQLReady(args))
            );
            State.CodaProcessState.Started(
              args,
              IdentSet.add(pendingIdent, extraIdents),
              p,
            );
          | Error(str) =>
            resolveFailed(str, extraIdents);
            State.CodaProcessState.Stopped(Result.fail(str));
          };
        };

        let killCoda = process => {
          CodaProcess.kill(process);
          State.CodaProcessState.Stopped(Belt.Result.Ok());
        };

        {
          ...acc,
          State.coda:
            switch (acc.coda, maybeArgs) {
            // we want to stop coda
            | (State.CodaProcessState.Stopped(_), None) =>
              resolveKilled(IdentSet.empty);
              acc.coda;
            | (State.CodaProcessState.Started(_, idents, proc), None) =>
              let state = killCoda(proc);
              resolveKilled(idents);
              state;
            | (State.CodaProcessState.Ready(_, proc), None) =>
              let state = killCoda(proc);
              resolveKilled(IdentSet.empty);
              state;
            // we want to start coda
            | (State.CodaProcessState.Stopped(_), Some(args)) =>
              startCoda(IdentSet.empty, args)
            // we've already started coda with this args
            | (State.CodaProcessState.Started(args, idents, p), Some(args'))
                when List.equal(~a_equal=(==), args, args') =>
              State.CodaProcessState.Started(
                args,
                // we'll resolve this whenever we wake up ready
                IdentSet.add(pendingIdent, idents),
                p,
              )
            | (State.CodaProcessState.Ready(args, _), Some(args'))
                when List.equal(~a_equal=(==), args, args') =>
              resolveReady(IdentSet.empty);
              acc.coda;
            // we've already started coda with other args
            | (State.CodaProcessState.Ready(_, proc), Some(args)) =>
              ignore(killCoda(proc));
              startCoda(IdentSet.empty, args);
            | (State.CodaProcessState.Started(_, idents, proc), Some(args)) =>
              ignore(killCoda(proc));
              startCoda(idents, args);
            },
        };
      };
  };

  module Store = {
    type state = State.t(CodaProcess.t, Window.t);
    type action = Action.t(Window.t);

    type t = {
      mutable state,
      onNewState: (state, state) => unit,
    };

    let create = (initialState, ~onNewState) => {
      state: initialState,
      onNewState,
    };

    // we need the extra unit because of value-restriction
    let apply = () => {
      let applyTmp: ref((t, action) => unit) = ref((_, _) => ());
      applyTmp :=
        (
          (store, action) => {
            let oldState = store.state;
            let apply': (t, action) => unit = applyTmp^;
            store.state =
              reduce(~dispatch=apply'(store), store.state, action);
            store.onNewState(oldState, store.state);
          }
        );
      applyTmp^;
    };
  };
};

module Window = {
  type t = BsElectron.BrowserWindow.t;
  include AppWindow;
};

include Make(DaemonProcess.CodaProcess, Window);
