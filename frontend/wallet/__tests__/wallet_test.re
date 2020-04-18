open Jest;
open Expect;
open Tc;

describe("setTimeout", () => {
  testAsync(
    "setTimeout finishes successfully",
    ~timeout=50,
    cb => {
      let (_, task) = Bindings.setTimeout(10);
      Task.perform(task, ~f=v => cb(expect(v) |> toEqual(`Finished)));
    },
  );

  testAsync(
    "setTimeout cancelled synchronously",
    ~timeout=50,
    cb => {
      let (`Canceller(cancel), task) = Bindings.setTimeout(10);
      cancel();
      Task.perform(task, ~f=v => cb(expect(v) |> toEqual(`Cancelled)));
    },
  );

  testAsync(
    "setTimeout cancelled asynchronously",
    ~timeout=50,
    cb => {
      let (`Canceller(cancel), t1) = Bindings.setTimeout(10);
      let (_, t2) = Bindings.setTimeout(1);
      let t2 = t2 |> Task.map(~f=_ => cancel());
      let task = Task.map2(t1, t2, ~f=(v, _) => v);
      Task.perform(task, ~f=v => cb(expect(v) |> toEqual(`Cancelled)));
    },
  );

  testAsync(
    "setTimeout cancelled too late",
    ~timeout=50,
    cb => {
      let (`Canceller(cancel), t1) = Bindings.setTimeout(10);
      let (_, t2) = Bindings.setTimeout(30);
      let t2 = t2 |> Task.map(~f=_ => cancel());
      let task = Task.map2(t1, t2, ~f=(v, _) => v);
      Task.perform(task, ~f=v => cb(expect(v) |> toEqual(`Finished)));
    },
  );
});
module Typ = {
  type t('a) =
    | Int: t(int)
    | Str: t(string);

  let if_eq =
      (
        type a,
        type b,
        ta: t(a),
        tb: t(b),
        v: b,
        ~is_equal: a => unit,
        ~not_equal: b => unit,
      ) => {
    switch (ta, tb) {
    | (Int, Int) => is_equal(v)
    | (Str, Str) => is_equal(v)
    | (_, _) => not_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

describe("CallTable", () => {
  testAsync(
    "pending task completes synchronously",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingInt: CallTable.Pending.t('x, int) =
        CallTable.nextPending(table, Typ.Int, ~loc=__LOC__);
      CallTable.resolve(table, pendingInt.ident, 1);
      Task.perform(pendingInt.task, ~f=i => cb(expect(i) |> toBe(1)));
    },
  );

  testAsync(
    "pending int task completes",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingInt: CallTable.Pending.t('x, int) =
        CallTable.nextPending(table, Typ.Int, ~loc=__LOC__);
      Task.perform(pendingInt.task, ~f=i => cb(expect(i) |> toBe(1)));

      let _ =
        Js.Global.setTimeout(
          () => CallTable.resolve(table, pendingInt.ident, 1),
          1,
        );
      ();
    },
  );

  testAsync(
    "pending str task completes",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingStr: CallTable.Pending.t('x, string) =
        CallTable.nextPending(table, Typ.Str, ~loc=__LOC__);
      Task.perform(pendingStr.task, ~f=s => cb(expect(s) |> toBe("hello")));

      let _ =
        Js.Global.setTimeout(
          () => CallTable.resolve(table, pendingStr.ident, "hello"),
          1,
        );
      ();
    },
  );
});

describe("Bindings", () =>
  describe("Spawn", () => {
    open Bindings;
    testAsync(
      "echo and get stdout",
      ~timeout=10,
      cb => {
        let echoProcess =
          ChildProcess.spawn(
            "echo",
            [|"hello"|],
            ChildProcess.spawnOptions(~stdio=ChildProcess.pipe, ()),
          );
        let stdout = ChildProcess.Process.stdoutGet(echoProcess);
        Stream.Readable.on(stdout, "data", data =>
          cb(expect(Node.Buffer.toString(data)) |> toEqual("hello\n"))
        );
      },
    );
    testAsync(
      "kill sleep and get exit code",
      ~timeout=10,
      cb => {
        let pauseProcess =
          ChildProcess.spawn(
            "sleep",
            [|"10"|],
            ChildProcess.spawnOptions(~stdio=ChildProcess.ignore, ()),
          );
        ChildProcess.Process.onExit(
          pauseProcess,
          fun
          | `Code(n) =>
            failwith(Printf.sprintf("Unexpected exit via code: %d", n))
          | `Signal(s) => cb(expect(s) |> toEqual("SIGINT")),
        );
        ChildProcess.Process.kill(pauseProcess, "SIGINT");
      },
    );
    testAsync(
      "detect error",
      ~timeout=10,
      cb => {
        let pauseProcess =
          ChildProcess.spawn(
            "this-program-doesn't-exist",
            [||],
            ChildProcess.spawnOptions(~stdio=ChildProcess.ignore, ()),
          );
        ChildProcess.Process.onError(pauseProcess, _ => cb(pass));
      },
    );
  })
);

let ellipsis = {js|…|js};

describe("CurrencyFormatter", () => {
  describe("toFormattedString", () => {
    test("1 nanocoda", () => {
      expect(CurrencyFormatter.toFormattedString(Int64.of_int(1)))
      |> toBe("0.0000000" ++ ellipsis)
    });
    test("90 coda", () => {
      expect(
        CurrencyFormatter.toFormattedString(Int64.of_string("90000000000")),
      )
      |> toBe("90")
    });
    test("no trailing zeroes", () => {
      expect(CurrencyFormatter.toFormattedString(Int64.of_int(100)))
      |> toBe("0.0000001")
    });
    test("fails on negative", () => {
      expect(() =>
        CurrencyFormatter.toFormattedString(Int64.of_int(-1))
      )
      |> toThrow
    });
  });
  describe("ofFormattedString", () => {
    test("1 nanocoda", () => {
      expect(CurrencyFormatter.ofFormattedString("0.000000001"))
      |> toEqual(Int64.of_string("1"))
    });
    test("90 coda", () => {
      expect(CurrencyFormatter.ofFormattedString("90"))
      |> toEqual(Int64.of_string("90000000000"))
    });
    test("no trailing zeroes", () => {
      expect(CurrencyFormatter.ofFormattedString("0.0000001"))
      |> toEqual(Int64.of_string("100"))
    });
    test("fails on negative", () => {
      expect(() =>
        CurrencyFormatter.ofFormattedString("-1")
      ) |> toThrow
    });
  });
});

describe("Time", () => {
  let testNow =
    Js.Date.makeWithYMDHMS(
      ~year=2019.,
      ~month=0.,
      ~date=23.,
      ~hours=14.,
      ~minutes=33.,
      ~seconds=22.,
      (),
    );
  let f = Time.render(~now=testNow);
  test("same day ago", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=2.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("2:33am");
  });
  test("same day midnightish am", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=0.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("12:33am");
  });
  test("same day pm", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=13.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("1:33pm");
  });
  test("same day noonish pm", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=12.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("12:33pm");
  });

  test("further back ago", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2018.,
        ~month=5.,
        ~date=23.,
        ~hours=12.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("June 23rd - 12:33pm");
  });
});

describe("AddressBook", () =>
  describe("serialization", () =>
    test("roundtrip", () => {
      let before =
        Js.Dict.fromList([
          ("pk1", Js.Json.string("name")),
          ("pk2", Js.Json.string("name 2")),
          ("pk3", Js.Json.string("name-3")),
        ])
        |> Js.Json.object_
        |> Js.Json.stringify;

      let after =
        before |> AddressBook.fromJsonString |> AddressBook.toJsonString;

      expect(before) |> toEqual(after);
    })
  )
);

module TestProcess = {
  module Counts = {
    type t = {
      stopped: int,
      started: int,
    };

    let empty = {stopped: 0, started: 0};

    // HACK: counts keyed on the first arg used (so we can differentiate between
    // tests).
    let t: Js.Dict.t(t) = Js.Dict.empty();

    let key = args => List.getAt(~index=0, args) |> Option.getExn;

    let get = args => {
      Js.Dict.get(t, key(args)) |> Option.getExn;
    };

    let zero = args => {
      Js.Dict.set(t, key(args), empty);
    };

    let write = (counts, args) => {
      Js.Dict.set(t, key(args), counts(get(args)));
    };

    let stop = write(c => {...c, stopped: c.stopped + 1});
    let start = write(c => {...c, started: c.started + 1});
  };

  module CallTable = Messages.CallTable;

  let callTable = CallTable.make();

  module State = {
    type t =
      | Stopped
      | Started
      | Ready;
  };

  type t = {
    pending: Messages.CallTable.Pending.t(Tablecloth.Never.t, string),
    state: ref(State.t),
    args: list(string),
  };

  let exit = (t: t, signal: option(string)) => {
    assert(t.state^ != State.Stopped);
    Counts.stop(t.args);
    t.state := State.Stopped;
    CallTable.resolve(
      callTable,
      t.pending.ident,
      Option.withDefault(~default="", signal),
    );
  };

  let waitExit = (t: t) => {
    let res: Task.t('x, [> | `Code(int) | `Signal(string)]) =
      t.pending.task
      |> Task.map(~f=s => s == "" ? `Code(0) : `Signal(s))
      // it's a unit test, so who cares if we obj.magic
      |> Obj.magic;
    res;
  };

  let stop = (t: t) => exit(t, None);

  let crash = (t: t) => exit(t, Some("CRASH"));

  let kill = (t: t) => exit(t, Some("SIGINT"));

  let start = args => {
    let pending =
      CallTable.nextPending(callTable, Messages.Typ.String, ~loc=__LOC__);
    let t = {state: ref(State.Started), args, pending};
    Counts.start(args);
    t;
  };
};

module TestWindow = {
  module CallTable = Messages.CallTable;

  let callTable = CallTable.make();

  type t = ref(list(Messages.mainToRendererMessages));

  let controlCodaDaemon = maybeArgs => Action.ControlCoda(maybeArgs);

  let send = (t, message) => {
    t := [message, ...t^];
  };
};

module TestApplication = Application.Make(TestProcess, TestWindow);

describe("ApplicationReducer", () => {
  let baseState = {
    Application.State.coda:
      Application.State.CodaProcessState.Stopped(Belt.Result.Ok()),
    window: Some(ref([])),
  };

  describe("CodaProcess", () => {
    let getTask = t => snd(t);

    module Counts = TestProcess.Counts;

    module Machine = {
      type t = {
        store: TestApplication.Store.t,
        dispatch: TestApplication.Store.action => unit,
      };

      let create = () => {
        let initial = {
          ...baseState,
          coda: Application.State.CodaProcessState.Stopped(Belt.Result.Ok()),
        };
        let store =
          TestApplication.Store.create(
            initial, ~onNewState=(_oldState, _state) =>
            ()
          );
        let dispatch = TestApplication.Store.apply((), store);
        {store, dispatch};
      };

      let foldCoda = (t, ~initial, ~started, ~stopped, ~willStart) => {
        let state = TestApplication.Store.currentState(t.store);
        switch (state.coda) {
        | Application.State.CodaProcessState.Started(args', p) =>
          started(initial, args', p)
        | Stopped(res) => stopped(initial, res)
        | WillStart(args, canceller) => willStart(initial, args, canceller)
        };
      };

      let checkCodaState = (t, ~started, ~stopped, ~willStart) =>
        foldCoda(
          t,
          ~initial=(),
          ~started=() => started,
          ~stopped=() => stopped,
          ~willStart=() => willStart,
        );
    };

    test("Start a stopped Coda", () => {
      let args = ["test0", "a", "b"];
      let m = Machine.create();
      Counts.zero(args);
      let action = TestWindow.controlCodaDaemon(Some(args));
      m.dispatch(action);

      Machine.checkCodaState(
        m,
        ~started=
          (args', p) =>
            expect((args', p.state^))
            |> toEqual((args', TestProcess.State.Started)),
        ~stopped=_ => failwith("Bad state, should have started"),
        ~willStart=(_, _) => failwith("Bad state, should have started"),
      );
    });

    testAsync(
      "Start a stopped Coda few times with the same args",
      ~timeout=300,
      cb => {
        let args = ["test1", "a", "b"];
        let m = Machine.create();
        Counts.zero(args);

        let run = () => {
          m.dispatch(TestWindow.controlCodaDaemon(Some(args)));
        };

        let task =
          Task.map3(
            // start it immediately
            Task.succeed(run()),
            // start it after some time
            getTask(Bindings.setTimeout(5)) |> Task.map(~f=_ => run()),
            // start and again
            getTask(Bindings.setTimeout(50)) |> Task.map(~f=_ => run()),
            ~f=((), (), ()) =>
            ()
          );

        Task.perform(task, ~f=() =>
          Machine.checkCodaState(
            m,
            ~started=
              (args', p) =>
                cb(
                  expect((args', p.state^, Counts.get(args).started))
                  |> toEqual((args', TestProcess.State.Started, 1)),
                ),
            ~stopped=_ => failwith("Bad state, should have started"),
            ~willStart=(_, _) => failwith("Bad state, should have started"),
          )
        );
      },
    );

    testAsync(
      "Stop a coda",
      ~timeout=300,
      cb => {
        let args = ["test2", "a", "b"];
        let m = Machine.create();
        Counts.zero(args);

        // start coda
        m.dispatch(TestWindow.controlCodaDaemon(Some(args)));

        // after we're ready, stop it
        let task =
          getTask(Bindings.setTimeout(1))
          |> Task.map(~f=_ => {
               Machine.checkCodaState(
                 m,
                 ~started=(_args', _p) => (),
                 ~stopped=_ => failwith("Bad state, should have started"),
                 ~willStart=
                   (_, _) => failwith("Bad state, should have started"),
               );

               m.dispatch(TestWindow.controlCodaDaemon(None));
             })
          |> Task.andThen(~f=() => getTask(Bindings.setTimeout(10)));

        Task.perform(
          task,
          ~f=_ => {
            let counts = Counts.get(args);

            Machine.checkCodaState(
              m,
              ~started=(_, _) => failwith("Bad state, should be stopped"),
              ~stopped=
                res =>
                  cb(
                    expect((res, counts.stopped))
                    |> toEqual((Belt.Result.Error(`Signal("SIGINT")), 1)),
                  ),
              ~willStart=
                (_, _) => failwith("Bad state, should have started"),
            );
          },
        );
      },
    );

    testAsync(
      "Start coda with different args",
      ~timeout=500,
      cb => {
        let args1 = ["test3", "a", "b"];
        let args2 = ["test3", "a", "b", "c"];
        let m = Machine.create();
        Counts.zero(args1);

        // start coda
        m.dispatch(TestWindow.controlCodaDaemon(Some(args1)));

        // exit for the first one
        let exitFirst =
          Machine.checkCodaState(
            m,
            ~started=(_args', p) => TestProcess.waitExit(p),
            ~willStart=
              (_, _) =>
                failwith("Bad state, should have started (willstart1)"),
            ~stopped=
              _ => failwith("Bad state, should have started (stopped)"),
          );

        // after we're ready, start it again with different args
        let task =
          getTask(Bindings.setTimeout(1))
          |> Task.map(~f=_ =>
               m.dispatch(TestWindow.controlCodaDaemon(Some(args2)))
             );

        // after a longer while, will-start will have actually started
        let waitLonger =
          getTask(Bindings.setTimeout(300))
          |> Task.map(~f=_ =>
               Machine.checkCodaState(
                 m,
                 ~started=(_args', _p) => (),
                 ~stopped=
                   _ => failwith("Bad state, should have started (stopped)"),
                 ~willStart=
                   (_, _) =>
                     failwith("Bad state, should have started (willstart2)"),
               )
             );

        let results =
          Task.map3(exitFirst, task, waitLonger, ~f=(s, (), ()) => s);

        Task.perform(results, ~f=s =>
          Machine.checkCodaState(
            m,
            ~started=
              (args', p) =>
                cb(
                  expect((args', p.state^, Counts.get(args2).started, s))
                  |> toEqual((
                       args',
                       TestProcess.State.Started,
                       2,
                       `Signal("SIGINT"),
                     )),
                ),
            ~stopped=_ => failwith("Bad state, should have started"),
            ~willStart=(_, _) => failwith("Bad state, should have started"),
          )
        );
      },
    );

    testAsync(
      "Wait for coda to die (successful)",
      ~timeout=200,
      cb => {
        let args = ["test4", "a", "b"];
        let m = Machine.create();
        Counts.zero(args);

        // start coda
        m.dispatch(TestWindow.controlCodaDaemon(Some(args)));

        let exitTask =
          Machine.checkCodaState(
            m,
            ~started=(_args', p) => TestProcess.waitExit(p),
            ~stopped=_ => failwith("Bad state, should have started"),
            ~willStart=(_, _) => failwith("Bad state, should have started"),
          );

        // after a bit, stop the process
        let task =
          getTask(Bindings.setTimeout(30))
          |> Task.map(~f=_ =>
               Machine.checkCodaState(
                 m,
                 ~started=(_args', p) => TestProcess.stop(p),
                 ~stopped=_ => failwith("Bad state, should have started"),
                 ~willStart=
                   (_, _) => failwith("Bad state, should have started"),
               )
             );

        let results = Task.map2(exitTask, task, ~f=(s, ()) => s);

        Task.perform(
          results,
          ~f=
            fun
            | `Signal(_) =>
              failwith("Bad state, should be exited with a code")
            | `Code(c) => cb(expect(c) |> toBe(0)),
        );
      },
    );

    let codaDiesTest = (~haltProcess, ~expectedExitResult, cb) => {
      let args = ["test5", "a", "b"];
      let m = Machine.create();
      Counts.zero(args);

      // start coda
      m.dispatch(TestWindow.controlCodaDaemon(Some(args)));

      let exitTask =
        Machine.checkCodaState(
          m,
          ~started=(_args', p) => TestProcess.waitExit(p),
          ~stopped=_ => failwith("Bad state, should have started"),
          ~willStart=(_, _) => failwith("Bad state, should have started"),
        );

      // after a bit, stop the process
      let task =
        getTask(Bindings.setTimeout(30))
        |> Task.map(~f=_ =>
             Machine.checkCodaState(
               m,
               ~started=(_args', p) => haltProcess(p),
               ~stopped=_ => failwith("Bad state, should have started"),
               ~willStart=
                 (_, _) => failwith("Bad state, should have started"),
             )
           );

      let results = Task.map2(exitTask, task, ~f=(s, ()) => s);

      Task.perform(results, ~f=r =>
        cb(expect(r) |> toEqual(expectedExitResult))
      );
    };

    testAsync(
      "Wait for coda to die (successfully)",
      ~timeout=200,
      codaDiesTest(
        ~haltProcess=TestProcess.stop,
        ~expectedExitResult=`Code(0),
      ),
    );

    testAsync(
      "Wait for coda to die (crash)",
      ~timeout=200,
      codaDiesTest(
        ~haltProcess=TestProcess.crash,
        ~expectedExitResult=`Signal("CRASH"),
      ),
    );
  });
});
