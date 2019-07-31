open Tc;

module State = {
  module CodaProcessState = {
    type t('proc) =
      // the process is stopped at time timestamp
      // it can be stopped unexpectedly with a string
      | Stopped(Result.t([ | `Signal(string) | `Code(int)], unit))
      // we will start coda after a bit of waiting for the last process to die
      | WillStart(list(string), [ | `Canceller(unit => unit)])
      // we started it with the following extra arguments
      | Started(list(string), 'proc);

    let toString =
      fun
      | Stopped(res) => {j|Stopped($res)|j}
      | WillStart(args, _canceller) => {j|WillStart($args)|j}
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

           let start: list(string) => t;
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
    | CodaStarted(args, p) => {...acc, State.coda: Started(args, p)}
    | CodaCrashed(message) => {
        ...acc,
        State.coda:
          switch (acc.coda) {
          | Stopped(_)
          | WillStart(_, _)
          | Started(_, _) => Stopped(Belt.Result.Error(message))
          },
      }
    | ControlCoda(maybeArgs) => {
        let startCoda = args => {
          let p = CodaProcess.start(args);
          Task.perform(
            CodaProcess.waitExit(p),
            ~f=
              fun
              | `Code(code) as c =>
                code == 0 ? () : dispatch(Action.CodaCrashed(c))
              | `Signal(_) as s => dispatch(Action.CodaCrashed(s)),
          );
          p;
        };

        let delayStartCoda = args => {
          let (canceller, task) = Bindings.setTimeout(100);
          Task.perform(
            task,
            ~f=
              fun
              | `Cancelled => {
                  ();
                }
              | `Finished => {
                  let p = startCoda(args);
                  dispatch(Action.CodaStarted(args, p));
                },
          );
          State.CodaProcessState.WillStart(args, canceller);
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
            | (
                State.CodaProcessState.WillStart(_, `Canceller(cancel)),
                None,
              ) =>
              cancel();
              acc.coda;
            | (State.CodaProcessState.Started(_, proc), None) =>
              killCoda(proc)

            // we want to start coda
            | (State.CodaProcessState.Stopped(_), Some(args)) =>
              let p = startCoda(args);
              State.CodaProcessState.Started(args, p);
            // we've already started coda with these args
            | (State.CodaProcessState.Started(args, _), Some(args'))
                when List.equal(~a_equal=(==), args, args') =>
              acc.coda
            // we are about to start coda with these args already
            | (State.CodaProcessState.WillStart(args, _), Some(args'))
                when List.equal(~a_equal=(==), args, args') =>
              acc.coda
            // we've already started coda with other args
            | (State.CodaProcessState.Started(_, proc), Some(args)) =>
              ignore(killCoda(proc));
              // we need the delay so proc has some time to cleanup
              delayStartCoda(args);
            // we are about to start coda with other args
            | (
                State.CodaProcessState.WillStart(_, `Canceller(cancel)),
                Some(args),
              ) =>
              cancel();
              delayStartCoda(args);
            },
        };
      };
  };

  module Store = {
    type state = State.t(CodaProcess.t, Window.t);
    type action = Action.t(Window.t, CodaProcess.t);

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
