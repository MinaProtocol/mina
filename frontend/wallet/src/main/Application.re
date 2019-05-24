open Tc;

module State = {
  module CodaProcessState = {
    type t('proc) =
      // the process is stopped
      // it can be stopped unexpectedly with a string
      | Stopped(Result.t([ | `Signal(string) | `Code(int)], unit))
      // we started it with the following extra arguments
      | Started(list(string), 'proc);

    let toString =
      fun
      | Stopped(res) => {j|Stopped($res)|j}
      | Started(args, proc) => {j|Started($args, $proc)|j};
  };

  type t('proc, 'window) = {
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

           let waitExit:
             t => Task.t('x, [> | `Code(int) | `Signal(string)]);

           let start: list(string) => Result.t(string, t);
         },
         Window: {
           type t;

           let send: (t, Messages.mainToRendererMessages) => unit;
         },
       ) => {
  module IdentSet = Messages.CallTable.Ident.Encode.Set;

  let reduce = (~dispatch, acc) => {
    fun
    | Action.PutWindow(windowOpt) => {...acc, State.window: windowOpt}
    | CodaCrashed(message) => {
        ...acc,
        State.coda:
          switch (acc.coda) {
          | Stopped(_)
          | Started(_, _) => Stopped(Belt.Result.Error(message))
          },
      }
    | ControlCoda(maybeArgs) => {
        let startCoda = args => {
          switch (CodaProcess.start(args)) {
          | Belt.Result.Ok(p) =>
            Task.perform(
              CodaProcess.waitExit(p),
              ~f=
                fun
                | `Code(code) as c =>
                  code == 0 ? () : dispatch(Action.CodaCrashed(c))
                | `Signal(_) as s => dispatch(Action.CodaCrashed(s)),
            );
            State.CodaProcessState.Started(args, p);
          | Error(str) =>
            State.CodaProcessState.Stopped(
              Result.fail(`Signal("Unknown: " ++ str)),
            )
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
            | (State.CodaProcessState.Stopped(_), None) => acc.coda
            | (State.CodaProcessState.Started(_, proc), None) =>
              killCoda(proc)
            // we want to start coda
            | (State.CodaProcessState.Stopped(_), Some(args)) =>
              startCoda(args)
            // we've already started coda with these args
            | (State.CodaProcessState.Started(args, p), Some(args'))
                when List.equal(~a_equal=(==), args, args') =>
              State.CodaProcessState.Started(args, p)
            // we've already started coda with other args
            | (State.CodaProcessState.Started(_, proc), Some(args)) =>
              ignore(killCoda(proc));
              startCoda(args);
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

    let currentState = t => t.state;

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

include Make(DaemonProcess.CodaProcess, AppWindow);
